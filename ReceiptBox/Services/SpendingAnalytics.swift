//
//  SpendingAnalytics.swift
//  ReceiptBox
//
//  Pure, testable calculations derived from receipts. No persistence or
//  networking — these operate on whatever receipt list they're given.

import Foundation

struct CategoryTotal: Identifiable, Hashable {
    let category: SpendingCategory
    let amount: Decimal

    var id: SpendingCategory { category }
}

struct MonthPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let total: Decimal
}

struct HomeSummary {
    let currentMonthTotal: Decimal
    let previousMonthTotal: Decimal
    let categoryTotals: [CategoryTotal]
    let recentReceipts: [Receipt]
    let currency: Currency

    /// Percentage change vs. the previous month, or `nil` when there is
    /// no previous-month spending to compare against.
    var percentChange: Double? {
        guard previousMonthTotal > 0 else { return nil }
        let diff = NSDecimalNumber(decimal: currentMonthTotal - previousMonthTotal)
        let base = NSDecimalNumber(decimal: previousMonthTotal)
        return diff.dividing(by: base).doubleValue * 100
    }

    static func make(
        from receipts: [Receipt],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> HomeSummary {
        let currentMonthReceipts = receipts.filter {
            calendar.isDate($0.date, equalTo: referenceDate, toGranularity: .month)
        }
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        let previousMonthReceipts = receipts.filter {
            calendar.isDate($0.date, equalTo: previousMonthDate, toGranularity: .month)
        }

        let currentTotal = currentMonthReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
        let previousTotal = previousMonthReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }

        let grouped = Dictionary(grouping: currentMonthReceipts, by: \.category)
        let categoryTotals = grouped
            .map { CategoryTotal(category: $0.key, amount: $0.value.reduce(Decimal(0)) { $0 + $1.totalAmount }) }
            .sorted { $0.amount > $1.amount }

        let recent = receipts.sorted { $0.date > $1.date }.prefix(5)

        return HomeSummary(
            currentMonthTotal: currentTotal,
            previousMonthTotal: previousTotal,
            categoryTotals: categoryTotals,
            recentReceipts: Array(recent),
            currency: receipts.first?.currency ?? .krw
        )
    }
}

struct AnalyticsSummary {
    let monthlyTrend: [MonthPoint]
    let categoryTotals: [CategoryTotal]
    let totalSpent: Decimal
    let currency: Currency

    static func make(
        from receipts: [Receipt],
        calendar: Calendar = .current,
        referenceDate: Date = .now,
        monthsBack: Int = 6
    ) -> AnalyticsSummary {
        var points: [MonthPoint] = []
        for offset in stride(from: monthsBack - 1, through: 0, by: -1) {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let total = receipts
                .filter { calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month) }
                .reduce(Decimal(0)) { $0 + $1.totalAmount }
            points.append(MonthPoint(date: monthDate, total: total))
        }

        let grouped = Dictionary(grouping: receipts, by: \.category)
        let categoryTotals = grouped
            .map { CategoryTotal(category: $0.key, amount: $0.value.reduce(Decimal(0)) { $0 + $1.totalAmount }) }
            .sorted { $0.amount > $1.amount }

        return AnalyticsSummary(
            monthlyTrend: points,
            categoryTotals: categoryTotals,
            totalSpent: receipts.reduce(Decimal(0)) { $0 + $1.totalAmount },
            currency: receipts.first?.currency ?? .krw
        )
    }
}

/// A natural, calendar-month grouping of receipts for the full Receipts
/// list — "This Month" / "Last Month" then wide month names further back,
/// matching the relative-date convention Mail and Messages use.
struct ReceiptGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let receipts: [Receipt]
}

enum ReceiptGrouping {
    static func byMonth(
        _ receipts: [Receipt],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> [ReceiptGroup] {
        let sorted = receipts.sorted { $0.date > $1.date }
        let grouped = Dictionary(grouping: sorted) { receipt in
            calendar.dateInterval(of: .month, for: receipt.date)?.start ?? receipt.date
        }

        return grouped.keys.sorted(by: >).map { monthStart in
            ReceiptGroup(
                id: monthStart.formatted(.iso8601),
                title: title(for: monthStart, calendar: calendar, referenceDate: referenceDate),
                receipts: grouped[monthStart] ?? []
            )
        }
    }

    private static func title(for monthStart: Date, calendar: Calendar, referenceDate: Date) -> String {
        if calendar.isDate(monthStart, equalTo: referenceDate, toGranularity: .month) {
            return String(localized: "이번 달")
        }
        if let lastMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate),
           calendar.isDate(monthStart, equalTo: lastMonth, toGranularity: .month) {
            return String(localized: "지난달")
        }
        return monthStart.formatted(.dateTime.month(.wide).year())
    }
}

/// Aggregates receipts by merchant into the existing `Store` shape —
/// replaces the static SampleData.stores list Analytics used to show, with
/// numbers computed from whatever receipts actually exist.
///
/// Grouping uses `TextNormalization.normalizedForMatching` (trim + case
/// fold) so "CU" and " cu " count as the same store, but nothing fuzzier
/// than that: a merchant name that includes a branch ("CU 신촌점" vs.
/// "CU 강남점") stays its own entry rather than being merged into a generic
/// "CU", since that merge could attribute one branch's spending to another.
enum StoreAnalytics {
    static func summarize(_ receipts: [Receipt]) -> [Store] {
        let grouped = Dictionary(grouping: receipts) { receipt in
            TextNormalization.normalizedForMatching(receipt.merchantName)
        }

        return grouped.values.compactMap { group -> Store? in
            guard let mostRecent = group.max(by: { $0.date < $1.date }),
                  !TextNormalization.normalizedForMatching(mostRecent.merchantName).isEmpty
            else { return nil }

            let total = group.reduce(Decimal(0)) { $0 + $1.totalAmount }
            return Store(
                name: mostRecent.merchantName.trimmingCharacters(in: .whitespacesAndNewlines),
                category: mostRecent.category,
                visitCount: group.count,
                totalSpent: total,
                lastVisit: mostRecent.date
            )
        }
        .sorted { $0.totalSpent > $1.totalSpent }
    }
}

/// Free-text search across the fields a "what did I buy" query would
/// plausibly match: merchant, item names, and category.
enum ReceiptSearch {
    static func filter(_ receipts: [Receipt], query: String) -> [Receipt] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return receipts }

        let lowered = trimmed.lowercased()
        return receipts.filter { receipt in
            receipt.merchantName.lowercased().contains(lowered)
                || receipt.category.displayName.lowercased().contains(lowered)
                || receipt.items.contains { $0.name.lowercased().contains(lowered) }
        }
    }
}
