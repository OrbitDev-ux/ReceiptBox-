//
//  Receipt.swift
//  ReceiptBox
//

import Foundation

/// Plain value data with no UI dependency — explicitly `nonisolated` so it
/// can be constructed from any context (persistence mapping, tests, sample
/// data) without this project's default MainActor isolation getting in the
/// way.
nonisolated struct Receipt: Identifiable, Codable, Hashable {
    let id: UUID
    var merchantName: String
    var date: Date
    var totalAmount: Decimal
    var currency: Currency
    var category: SpendingCategory
    var paymentMethod: PaymentMethod
    var items: [ReceiptItem]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        merchantName: String,
        date: Date,
        totalAmount: Decimal,
        currency: Currency = .krw,
        category: SpendingCategory,
        paymentMethod: PaymentMethod,
        items: [ReceiptItem] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.merchantName = merchantName
        self.date = date
        self.totalAmount = totalAmount
        self.currency = currency
        self.category = category
        self.paymentMethod = paymentMethod
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var formattedTotal: String {
        totalAmount.formatted(as: currency)
    }
}
