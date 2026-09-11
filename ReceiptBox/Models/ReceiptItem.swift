//
//  ReceiptItem.swift
//  ReceiptBox
//

import Foundation

nonisolated struct ReceiptItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var quantity: Int
    var unitPrice: Decimal
    var category: SpendingCategory?
    /// Optional link to a normalized Product, for a future OCR/barcode
    /// reconciliation pass. Nothing populates this yet — no current flow
    /// writes it — it just gives that future work somewhere to land
    /// without another schema change.
    var productID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int = 1,
        unitPrice: Decimal,
        category: SpendingCategory? = nil,
        productID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.category = category
        self.productID = productID
    }

    var totalPrice: Decimal {
        unitPrice * Decimal(quantity)
    }
}
