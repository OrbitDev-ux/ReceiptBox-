//
//  PurchaseEntity.swift
//  ReceiptBox
//
//  SwiftData persistence model for Purchase. `productID` is kept as a plain
//  scalar column (not just the `product` relationship below) so domain
//  mapping never has to worry about a nil relationship — ProductStore
//  always sets both together when a purchase is created.

import Foundation
import SwiftData

@Model
final class PurchaseEntity {
    @Attribute(.unique) var id: UUID
    var productID: UUID
    var price: Decimal
    var currencyRaw: String
    var quantity: Int
    var storeName: String?
    var purchasedAt: Date
    var receiptID: UUID?
    var createdAt: Date
    var product: ProductEntity?

    init(
        id: UUID,
        productID: UUID,
        price: Decimal,
        currencyRaw: String,
        quantity: Int,
        storeName: String?,
        purchasedAt: Date,
        receiptID: UUID?,
        createdAt: Date
    ) {
        self.id = id
        self.productID = productID
        self.price = price
        self.currencyRaw = currencyRaw
        self.quantity = quantity
        self.storeName = storeName
        self.purchasedAt = purchasedAt
        self.receiptID = receiptID
        self.createdAt = createdAt
    }
}
