//
//  Product.swift
//  ReceiptBox
//
//  A normalized, barcode-identified product — the thing you buy again and
//  again, independent of any single receipt. `ProductStore` is the source
//  of truth for uniqueness (one Product per barcode); this struct is just
//  the plain value type the rest of the app works with.

import Foundation

nonisolated struct Product: Identifiable, Codable, Hashable {
    let id: UUID
    var barcode: String
    var name: String
    var brand: String?
    var category: SpendingCategory
    var unit: String?
    var imageURL: URL?
    /// True for products a person registered by hand (via "상품 직접 등록");
    /// false for the small built-in sample set. Not load-bearing for any
    /// logic today — a hook for surfacing provenance later.
    var isUserCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        barcode: String,
        name: String,
        brand: String? = nil,
        category: SpendingCategory = .other,
        unit: String? = nil,
        imageURL: URL? = nil,
        isUserCreated: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.category = category
        self.unit = unit
        self.imageURL = imageURL
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Barcodes coming from Vision/AVFoundation or a text field can carry
    /// incidental whitespace; this is the one place that gets cleaned up
    /// before a barcode is ever compared or persisted.
    static func normalizeBarcode(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
