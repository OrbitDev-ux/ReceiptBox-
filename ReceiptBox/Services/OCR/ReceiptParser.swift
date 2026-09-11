//
//  ReceiptParser.swift
//  ReceiptBox
//
//  Turns raw OCR lines into a ReceiptDraft. Receipt layouts vary a lot, so
//  this is a set of general heuristics (keyword + pattern matching) rather
//  than anything tied to one store's format. Pure and synchronous so it's
//  testable with plain string fixtures, independent of Vision or the
//  camera.

import Foundation

nonisolated enum ReceiptParser {
    // MARK: - Keyword tables

    private static let totalKeywords = [
        "합계", "합 계", "결제금액", "결제 금액", "총액", "총 액", "받을금액", "받을 금액",
        "판매금액", "total", "grand total", "amount due"
    ]
    private static let vatKeywords = ["부가세", "부가 세", "vat", "tax"]
    private static let noiseKeywords = [
        "사업자", "사업자번호", "대표자", "전화", "tel.", "tel:", "주소", "영수증",
        "receipt no", "승인번호", "승인 번호", "가맹점", "카드번호", "포인트", "적립",
        "매장번호", "registered", "receipt#", "수량", "단가", "품명"
    ]
    private static let cardKeywords = ["신용카드", "체크카드", "카드", "card"]
    private static let cashKeywords = ["현금", "cash"]

    private static let categoryKeywordMap: [(keywords: [String], category: SpendingCategory)] = [
        (["스타벅스", "starbucks", "카페", "커피", "coffee", "투썸", "이디야", "빽다방", "cafe"], .cafe),
        (["gs25", "cu ", "cu25", "세븐일레븐", "7-eleven", "이마트24", "마트", "편의점"], .grocery),
        (["맥도날드", "mcdonald", "버거킹", "burger", "롯데리아", "김밥", "분식", "국밥", "식당", "subway"], .food),
        (["올리브영", "백화점", "쇼핑몰", "coupang", "쿠팡", "apple store"], .shopping)
    ]

    // MARK: - Regex

    private static let numericDateRegex = #/(\d{4})[-./](\d{1,2})[-./](\d{1,2})/#
    private static let koreanDateRegex = #/(\d{2,4})년\s*(\d{1,2})월\s*(\d{1,2})일/#
    private static let amountRegex = #/\d{1,3}(?:,\d{3})+|\d+/#
    private static let quantityRegex = #/[xX×]\s*(\d+)|(\d+)\s*개/#

    // MARK: - Entry point

    static func parse(lines rawLines: [String]) -> ReceiptDraft {
        let lines = normalize(rawLines)

        guard !lines.isEmpty else {
            return ReceiptDraft(
                merchantName: nil,
                date: nil,
                total: nil,
                items: [],
                paymentMethod: nil,
                category: nil,
                lowConfidenceFields: [.merchant, .date, .total]
            )
        }

        var lowConfidence: Set<ReceiptDraft.Field> = []

        let date = extractDate(from: lines)
        if date == nil { lowConfidence.insert(.date) }

        let (total, totalIsConfident) = extractTotal(from: lines)
        if !totalIsConfident { lowConfidence.insert(.total) }

        let merchant = extractMerchant(from: lines)
        if merchant == nil { lowConfidence.insert(.merchant) }

        let items = extractItems(from: lines)
        let paymentMethod = extractPaymentMethod(from: lines)
        let category = merchant.flatMap(inferCategory)

        return ReceiptDraft(
            merchantName: merchant,
            date: date,
            total: total,
            items: items,
            paymentMethod: paymentMethod,
            category: category,
            lowConfidenceFields: lowConfidence
        )
    }

    // MARK: - Normalization

    private static func normalize(_ rawLines: [String]) -> [String] {
        let trimmed = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Vision occasionally emits the same line twice in a row (e.g. a
        // bold/overlapping print catching two overlapping observations).
        // Only *consecutive* duplicates are dropped — a price or item name
        // that legitimately repeats non-adjacently is left alone.
        var deduped: [String] = []
        for line in trimmed where line != deduped.last {
            deduped.append(line)
        }
        return deduped
    }

    // MARK: - Date

    private static func extractDate(from lines: [String]) -> Date? {
        for line in lines {
            if let match = line.firstMatch(of: numericDateRegex),
               let date = makeDate(yearText: match.1, monthText: match.2, dayText: match.3) {
                return date
            }
            if let match = line.firstMatch(of: koreanDateRegex),
               let date = makeDate(yearText: match.1, monthText: match.2, dayText: match.3) {
                return date
            }
        }
        return nil
    }

    private static func makeDate(yearText: Substring, monthText: Substring, dayText: Substring) -> Date? {
        guard var year = Int(yearText), let month = Int(monthText), let day = Int(dayText),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        if year < 100 { year += 2000 }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)
    }

    private static func isDateLine(_ line: String) -> Bool {
        line.contains(numericDateRegex) || line.contains(koreanDateRegex)
    }

    // MARK: - Total

    private static func extractTotal(from lines: [String]) -> (Decimal?, isConfident: Bool) {
        for line in lines {
            let lower = line.lowercased()
            guard totalKeywords.contains(where: { lower.contains($0) }) else { continue }
            if let amount = largestAmount(in: line), amount > 0 {
                return (amount, true)
            }
        }

        // Fallback: the largest currency-shaped number anywhere on the
        // receipt. Deliberately marked low-confidence — it's frequently
        // right (the total is usually the biggest number) but not reliably
        // so, and Review should draw the eye to it either way.
        let fallback = lines.compactMap { largestAmount(in: $0) }.max()
        return (fallback, false)
    }

    private static func largestAmount(in line: String) -> Decimal? {
        line.matches(of: amountRegex)
            .compactMap { match -> Decimal? in
                let raw = String(line[match.range]).replacingOccurrences(of: ",", with: "")
                return Decimal(string: raw)
            }
            .max()
    }

    // MARK: - Merchant

    private static func extractMerchant(from lines: [String]) -> String? {
        for line in lines.prefix(6) {
            guard !isNoiseLine(line), !isMostlyNumeric(line), !isDateLine(line) else { continue }
            guard line.count <= 24 else { continue }
            guard line.contains(where: \.isLetter) else { continue }
            return line
        }
        return nil
    }

    private static func isMostlyNumeric(_ line: String) -> Bool {
        // Threshold is deliberately high (not 50/50) so short alphanumeric
        // store names/branch codes like "GS25" or "CU25" still read as text.
        let digitCount = line.filter(\.isNumber).count
        return Double(digitCount) / Double(max(line.count, 1)) > 0.6
    }

    private static func isNoiseLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if noiseKeywords.contains(where: { lower.contains($0) }) { return true }
        if totalKeywords.contains(where: { lower.contains($0) }) { return true }
        if vatKeywords.contains(where: { lower.contains($0) }) { return true }
        if cardKeywords.contains(where: { lower.contains($0) }) { return true }
        if cashKeywords.contains(where: { lower.contains($0) }) { return true }
        // Phone-number-ish: lots of digits and a separator.
        if line.contains("-"), line.filter(\.isNumber).count >= 6 { return true }
        return false
    }

    // MARK: - Items

    private static func extractItems(from lines: [String]) -> [ReceiptItem] {
        var items: [ReceiptItem] = []

        for line in lines {
            guard !isNoiseLine(line), !isDateLine(line) else { continue }
            guard let priceMatch = line.matches(of: amountRegex).last else { continue }

            let raw = String(line[priceMatch.range]).replacingOccurrences(of: ",", with: "")
            guard let price = Decimal(string: raw), price > 0 else { continue }

            let namePart = String(line[line.startIndex..<priceMatch.range.lowerBound])
            let name = cleanItemName(namePart)
            guard !name.isEmpty, name.count <= 40, name.contains(where: \.isLetter) else { continue }

            let quantity = extractQuantity(from: line) ?? 1
            items.append(ReceiptItem(name: name, quantity: quantity, unitPrice: price))
        }

        return items
    }

    private static func extractQuantity(from line: String) -> Int? {
        guard let match = line.firstMatch(of: quantityRegex) else { return nil }
        let text = match.output.1 ?? match.output.2
        guard let text else { return nil }
        return Int(text)
    }

    private static func cleanItemName(_ raw: String) -> String {
        var name = raw
        if let match = name.firstMatch(of: quantityRegex) {
            name.removeSubrange(match.range)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Payment method

    private static func extractPaymentMethod(from lines: [String]) -> PaymentMethod? {
        for line in lines {
            let lower = line.lowercased()
            if cardKeywords.contains(where: { lower.contains($0) }) { return .card }
            if cashKeywords.contains(where: { lower.contains($0) }) { return .cash }
        }
        return nil
    }

    // MARK: - Category

    private static func inferCategory(fromMerchant merchant: String) -> SpendingCategory? {
        let lower = merchant.lowercased()
        for entry in categoryKeywordMap where entry.keywords.contains(where: { lower.contains($0) }) {
            return entry.category
        }
        return nil
    }
}
