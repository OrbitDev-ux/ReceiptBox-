//
//  SampleData.swift
//  ReceiptBox
//
//  First-launch seed data only — ReceiptStore/ProductStore insert this into
//  SwiftData once, the first time their persistent store is empty (see
//  `seedSampleDataIfNeeded()`), and every screen reads real persisted data
//  from there on. Also reused as fixture data for previews/tests.

import Foundation

/// Plain static data with no UI dependency — explicitly `nonisolated` so it
/// can be referenced from default-parameter expressions (which evaluate in
/// a nonisolated context) without tripping this project's default
/// MainActor isolation.
nonisolated enum SampleData {
    static let receipts: [Receipt] = [
        Receipt(
            merchantName: "Starbucks",
            date: daysAgo(0),
            totalAmount: 6800,
            category: .cafe,
            paymentMethod: .card,
            items: [ReceiptItem(name: "Caffe Latte", quantity: 1, unitPrice: 6800)]
        ),
        Receipt(
            merchantName: "CU",
            date: daysAgo(1),
            totalAmount: 4500,
            category: .grocery,
            paymentMethod: .cash,
            items: [
                ReceiptItem(name: "Bottled Water", quantity: 1, unitPrice: 1500),
                ReceiptItem(name: "Snack", quantity: 1, unitPrice: 3000)
            ]
        ),
        Receipt(
            merchantName: "McDonald's",
            date: daysAgo(2),
            totalAmount: 9200,
            category: .food,
            paymentMethod: .card,
            items: [
                ReceiptItem(name: "Big Mac Set", quantity: 1, unitPrice: 8200),
                ReceiptItem(name: "McFlurry", quantity: 1, unitPrice: 1000)
            ]
        ),
        Receipt(
            merchantName: "Olive Young",
            date: daysAgo(4),
            totalAmount: 32000,
            category: .shopping,
            paymentMethod: .card
        ),
        Receipt(
            merchantName: "Apple",
            date: daysAgo(6),
            totalAmount: 259000,
            category: .shopping,
            paymentMethod: .card
        ),
        Receipt(
            merchantName: "Twosome Place",
            date: daysAgo(9),
            totalAmount: 7200,
            category: .cafe,
            paymentMethod: .mobilePay
        ),
        Receipt(
            merchantName: "GS25",
            date: daysAgo(13),
            totalAmount: 3200,
            category: .grocery,
            paymentMethod: .cash
        ),
        Receipt(
            merchantName: "Subway",
            date: daysAgo(18),
            totalAmount: 8900,
            category: .food,
            paymentMethod: .card
        ),
        Receipt(
            merchantName: "Coupang",
            date: daysAgo(22),
            totalAmount: 45000,
            category: .shopping,
            paymentMethod: .card
        ),
        Receipt(
            merchantName: "Kyobo Book Centre",
            date: daysAgo(27),
            totalAmount: 21000,
            category: .other,
            paymentMethod: .card
        ),

        // Previous month
        Receipt(
            merchantName: "Starbucks",
            date: daysAgo(35),
            totalAmount: 6200,
            category: .cafe,
            paymentMethod: .card
        ),
        Receipt(
            merchantName: "McDonald's",
            date: daysAgo(40),
            totalAmount: 7300,
            category: .food,
            paymentMethod: .cash
        ),
        Receipt(
            merchantName: "CU",
            date: daysAgo(46),
            totalAmount: 2900,
            category: .grocery,
            paymentMethod: .cash
        ),
        Receipt(
            merchantName: "Olive Young",
            date: daysAgo(52),
            totalAmount: 28000,
            category: .shopping,
            paymentMethod: .card
        ),
        Receipt(
            merchantName: "Apple",
            date: daysAgo(58),
            totalAmount: 259000,
            category: .shopping,
            paymentMethod: .card
        ),

        // Two months ago
        Receipt(
            merchantName: "GS25",
            date: daysAgo(68),
            totalAmount: 3600,
            category: .grocery,
            paymentMethod: .cash
        ),
        Receipt(
            merchantName: "Subway",
            date: daysAgo(75),
            totalAmount: 8100,
            category: .food,
            paymentMethod: .card
        ),

        // Three months ago
        Receipt(
            merchantName: "Coupang",
            date: daysAgo(100),
            totalAmount: 39000,
            category: .shopping,
            paymentMethod: .card
        ),
        Receipt(
            merchantName: "Starbucks",
            date: daysAgo(108),
            totalAmount: 6500,
            category: .cafe,
            paymentMethod: .card
        )
    ]

    // MARK: - Products / Purchases

    /// A small built-in set of convenience-store staples so the barcode
    /// flow has something to find on first launch. Barcodes are
    /// realistic-looking (Korean EAN-13 prefixes) but the prices below are
    /// illustrative test values, not real market prices.
    static let products: [Product] = [
        Product(barcode: "8801062973792", name: "펩시 제로", brand: "펩시", category: .grocery, unit: "355ml", isUserCreated: false),
        Product(barcode: "8801062971323", name: "코카콜라 제로", brand: "코카콜라", category: .grocery, unit: "355ml", isUserCreated: false),
        Product(barcode: "8809598720013", name: "제주삼다수", brand: "삼다수", category: .grocery, unit: "500ml", isUserCreated: false),
        Product(barcode: "8801121962045", name: "새우깡", brand: "농심", category: .grocery, unit: "90g", isUserCreated: false),
        Product(barcode: "8801043017893", name: "신라면", brand: "농심", category: .grocery, unit: "120g", isUserCreated: false)
    ]

    static let purchases: [Purchase] = [
        Purchase(productID: products[0].id, price: 1800, quantity: 1, storeName: "CU", purchasedAt: daysAgo(0)),
        Purchase(productID: products[0].id, price: 1700, quantity: 1, storeName: "GS25", purchasedAt: daysAgo(8)),
        Purchase(productID: products[0].id, price: 1800, quantity: 1, storeName: "CU", purchasedAt: daysAgo(16)),
        Purchase(productID: products[1].id, price: 1900, quantity: 2, storeName: "세븐일레븐", purchasedAt: daysAgo(3)),
        Purchase(productID: products[2].id, price: 900, quantity: 1, storeName: "CU", purchasedAt: daysAgo(1)),
        Purchase(productID: products[3].id, price: 1500, quantity: 1, storeName: "GS25", purchasedAt: daysAgo(5))
    ]

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
    }
}
