//
//  ProductAnalytics.swift
//  ReceiptBox
//
//  Pure, testable calculations derived from purchases/products, mirroring
//  SpendingAnalytics.swift. No persistence or networking — these operate on
//  whatever purchase/product list they're given, so they're usable directly
//  from ProductStore's in-memory arrays or from plain test fixtures.

import Foundation

/// A Product's price history is just its purchases sorted by date — there's
/// no separate stored entity for it, this is computed on demand.
struct PriceHistorySummary {
    let recentPrice: Decimal?
    let lowestPrice: Decimal?
    let highestPrice: Decimal?
    let averagePrice: Decimal?
    let purchaseCount: Int
    let recentStoreName: String?
    let recentPurchaseDate: Date?
    /// Newest first.
    let sortedPurchases: [Purchase]

    static func make(from purchases: [Purchase]) -> PriceHistorySummary {
        let sorted = purchases.sorted { $0.purchasedAt > $1.purchasedAt }
        guard !sorted.isEmpty else {
            return PriceHistorySummary(
                recentPrice: nil,
                lowestPrice: nil,
                highestPrice: nil,
                averagePrice: nil,
                purchaseCount: 0,
                recentStoreName: nil,
                recentPurchaseDate: nil,
                sortedPurchases: []
            )
        }

        let prices = sorted.map(\.price)
        let total = prices.reduce(Decimal(0), +)

        return PriceHistorySummary(
            recentPrice: sorted.first?.price,
            lowestPrice: prices.min(),
            highestPrice: prices.max(),
            averagePrice: total / Decimal(prices.count),
            purchaseCount: sorted.count,
            recentStoreName: sorted.first?.storeName,
            recentPurchaseDate: sorted.first?.purchasedAt,
            sortedPurchases: sorted
        )
    }
}

/// Free-text search across products — merchant-side counterpart to
/// ReceiptSearch. Unlike ReceiptSearch, an empty query yields no results
/// rather than "everything": this feeds an inline section under Receipts
/// search, which should stay empty until the person actually types
/// something product-shaped.
enum ProductSearch {
    static func filter(_ products: [Product], query: String) -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lowered = trimmed.lowercased()
        return products.filter { product in
            product.name.lowercased().contains(lowered)
                || (product.brand?.lowercased().contains(lowered) ?? false)
                || product.barcode.contains(trimmed)
                || product.category.displayName.lowercased().contains(lowered)
        }
    }
}
