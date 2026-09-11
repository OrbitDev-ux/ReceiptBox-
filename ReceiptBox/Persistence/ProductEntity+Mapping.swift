//
//  ProductEntity+Mapping.swift
//  ReceiptBox
//
//  Conversion between the SwiftData entities and the plain Product/Purchase
//  domain structs, mirroring ReceiptEntity+Mapping.swift.

import Foundation

extension ProductEntity {
    convenience init(product: Product) {
        self.init(
            id: product.id,
            barcode: product.barcode,
            name: product.name,
            brand: product.brand,
            categoryRaw: product.category.rawValue,
            unit: product.unit,
            imageURLString: product.imageURL?.absoluteString,
            isUserCreated: product.isUserCreated,
            createdAt: product.createdAt,
            updatedAt: product.updatedAt
        )
    }

    /// Updates everything except `barcode` and `id` — a product's identity
    /// shouldn't shift under an edit. `ProductStore.updateProduct` is the
    /// only caller.
    func updateScalarFields(from product: Product) {
        name = product.name
        brand = product.brand
        categoryRaw = product.category.rawValue
        unit = product.unit
        imageURLString = product.imageURL?.absoluteString
        updatedAt = .now
    }

    var asDomain: Product {
        Product(
            id: id,
            barcode: barcode,
            name: name,
            brand: brand,
            category: SpendingCategory(rawValue: categoryRaw) ?? .other,
            unit: unit,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            isUserCreated: isUserCreated,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension PurchaseEntity {
    convenience init(purchase: Purchase) {
        self.init(
            id: purchase.id,
            productID: purchase.productID,
            price: purchase.price,
            currencyRaw: purchase.currency.rawValue,
            quantity: purchase.quantity,
            storeName: purchase.storeName,
            purchasedAt: purchase.purchasedAt,
            receiptID: purchase.receiptID,
            createdAt: purchase.createdAt
        )
    }

    var asDomain: Purchase {
        Purchase(
            id: id,
            productID: productID,
            price: price,
            currency: Currency(rawValue: currencyRaw) ?? .krw,
            quantity: quantity,
            storeName: storeName,
            purchasedAt: purchasedAt,
            receiptID: receiptID,
            createdAt: createdAt
        )
    }
}
