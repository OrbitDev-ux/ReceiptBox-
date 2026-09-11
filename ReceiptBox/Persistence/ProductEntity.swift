//
//  ProductEntity.swift
//  ReceiptBox
//
//  SwiftData persistence model for Product. `barcode` is `.unique` at the
//  schema level — a second line of defense under ProductStore's own
//  check-before-create logic, not the primary mechanism.

import Foundation
import SwiftData

@Model
final class ProductEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String?
    var categoryRaw: String
    var unit: String?
    var imageURLString: String?
    var isUserCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PurchaseEntity.product)
    var purchases: [PurchaseEntity] = []

    init(
        id: UUID,
        barcode: String,
        name: String,
        brand: String?,
        categoryRaw: String,
        unit: String?,
        imageURLString: String?,
        isUserCreated: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.categoryRaw = categoryRaw
        self.unit = unit
        self.imageURLString = imageURLString
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
