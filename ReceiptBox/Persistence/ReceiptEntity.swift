//
//  ReceiptEntity.swift
//  ReceiptBox
//
//  SwiftData persistence models. These are intentionally separate from the
//  Receipt/ReceiptItem domain structs used throughout the UI — the entity
//  layer only exists to survive relaunches; everything else in the app
//  keeps working against the plain value types via ReceiptStore.

import Foundation
import SwiftData

@Model
final class ReceiptEntity {
    @Attribute(.unique) var id: UUID
    var merchantName: String
    var date: Date
    var totalAmount: Decimal
    var currencyRaw: String
    var categoryRaw: String
    var paymentMethodRaw: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ReceiptItemEntity.receipt)
    var items: [ReceiptItemEntity] = []

    init(
        id: UUID,
        merchantName: String,
        date: Date,
        totalAmount: Decimal,
        currencyRaw: String,
        categoryRaw: String,
        paymentMethodRaw: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.merchantName = merchantName
        self.date = date
        self.totalAmount = totalAmount
        self.currencyRaw = currencyRaw
        self.categoryRaw = categoryRaw
        self.paymentMethodRaw = paymentMethodRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ReceiptItemEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Int
    var unitPrice: Decimal
    var categoryRaw: String?
    /// Preserves input order within a receipt; SwiftData to-many
    /// relationships don't guarantee array order on their own.
    var sortIndex: Int
    /// See `ReceiptItem.productID` — unpopulated by any flow today.
    var productID: UUID?
    var receipt: ReceiptEntity?

    init(
        id: UUID,
        name: String,
        quantity: Int,
        unitPrice: Decimal,
        categoryRaw: String?,
        sortIndex: Int,
        productID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.categoryRaw = categoryRaw
        self.sortIndex = sortIndex
        self.productID = productID
    }
}
