//
//  Purchase.swift
//  ReceiptBox
//
//  One specific instance of buying a Product: what it cost, how many, where,
//  and when. A Product's "price history" is just its purchases sorted by
//  date — there's no separate history entity, `ProductAnalytics` derives it
//  from this list. `receiptID` is an optional, unenforced link back to a
//  Receipt for purchases that happened to come from a scanned/entered
//  receipt; barcode-flow purchases simply leave it nil.

import Foundation

nonisolated struct Purchase: Identifiable, Codable, Hashable {
    let id: UUID
    var productID: UUID
    var price: Decimal
    var currency: Currency
    var quantity: Int
    var storeName: String?
    var purchasedAt: Date
    var receiptID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        productID: UUID,
        price: Decimal,
        currency: Currency = .krw,
        quantity: Int = 1,
        storeName: String? = nil,
        purchasedAt: Date = .now,
        receiptID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.productID = productID
        self.price = price
        self.currency = currency
        self.quantity = quantity
        self.storeName = storeName
        self.purchasedAt = purchasedAt
        self.receiptID = receiptID
        self.createdAt = createdAt
    }

    var totalPrice: Decimal {
        price * Decimal(quantity)
    }
}
