//
//  ProductMatcher.swift
//  ReceiptBox
//
//  Decides whether a receipt item confidently refers to an *already
//  registered* Product. Deliberately conservative: this only links to an
//  existing Product, it never creates one — an item with no confident match
//  just stays a plain ReceiptItem, exactly as it does today.
//
//  There's no barcode-first branch here even though barcode is the
//  strongest possible signal (see ProductStore.product(forBarcode:), which
//  is exactly that for the barcode-scan flow) — OCR'd and manually typed
//  receipt items never carry a barcode, so name matching is the only signal
//  actually available on this path. When two or more registered products
//  share the same normalized name, that's ambiguous rather than confident,
//  so this backs off rather than guessing.
//
//  Pure and synchronous so it's testable without SwiftData, mirroring
//  ReceiptParser.
//

import Foundation

nonisolated enum ProductMatcher {
    static func match(itemName: String, existingProducts: [Product]) -> Product? {
        let target = TextNormalization.normalizedForMatching(itemName)
        guard !target.isEmpty else { return nil }

        let candidates = existingProducts.filter { TextNormalization.normalizedForMatching($0.name) == target }
        guard candidates.count == 1 else { return nil }
        return candidates.first
    }
}
