//
//  ReceiptDraft.swift
//  ReceiptBox
//
//  The output of parsing OCR text: receipt-shaped data the parser could
//  actually find, plus which fields it wasn't confident about. OCR results
//  can be wrong or incomplete, so this is deliberately optional/partial
//  rather than a plain Receipt — Review is where the user closes the gap.

import Foundation

nonisolated struct ReceiptDraft: Equatable {
    enum Field: Hashable {
        case merchant, date, total
    }

    var merchantName: String?
    var date: Date?
    var total: Decimal?
    var items: [ReceiptItem]
    var paymentMethod: PaymentMethod?
    var category: SpendingCategory?
    var lowConfidenceFields: Set<Field>

    var needsReview: Bool {
        merchantName == nil || total == nil || !lowConfidenceFields.isEmpty
    }

    /// Converts the draft into a real `Receipt`, filling anything missing
    /// with a neutral default so the Review form always has something
    /// sensible to show and the user corrects rather than starts from
    /// scratch.
    func asReceipt(fallbackDate: Date = .now) -> Receipt {
        let name = merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemsTotal = items.reduce(Decimal(0)) { $0 + $1.totalPrice }

        return Receipt(
            merchantName: (name?.isEmpty == false) ? name! : "",
            date: date ?? fallbackDate,
            totalAmount: total ?? itemsTotal,
            category: category ?? .other,
            paymentMethod: paymentMethod ?? .card,
            items: items
        )
    }
}
