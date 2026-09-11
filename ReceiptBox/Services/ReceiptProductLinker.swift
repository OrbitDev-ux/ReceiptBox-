//
//  ReceiptProductLinker.swift
//  ReceiptBox
//
//  Fills in ReceiptItem.productID for items that confidently match an
//  already-registered Product (see ProductMatcher), so a scanned or typed
//  receipt feeds Price History the same way a barcode purchase does.
//  Nothing here creates a Product or persists anything — Purchase creation
//  happens downstream, in ProductStore.syncPurchases(for:), which is what
//  actually reads the productID this sets.
//
//  Pure and synchronous, mirroring ReceiptParser/ProductMatcher.
//

import Foundation

nonisolated enum ReceiptProductLinker {
    /// Returns a copy of `receipt` with each item's `productID` set where a
    /// confident match exists against `existingProducts`. Re-matches every
    /// item regardless of whether it already carries a `productID`, so
    /// re-saving an edited receipt reflects the current product catalog
    /// (e.g. an ambiguous match that's since been resolved, or a product
    /// that no longer exists). Items with no confident match are left with
    /// `productID == nil` and stay ordinary ReceiptItem entries.
    static func linkedReceipt(_ receipt: Receipt, existingProducts: [Product]) -> Receipt {
        var linked = receipt
        linked.items = receipt.items.map { item in
            var item = item
            item.productID = ProductMatcher.match(itemName: item.name, existingProducts: existingProducts)?.id
            return item
        }
        return linked
    }
}
