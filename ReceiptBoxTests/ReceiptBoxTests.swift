//
//  ReceiptBoxTests.swift
//  ReceiptBoxTests
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import ReceiptBox

@MainActor
struct ReceiptBoxTests {

    // MARK: - Test helpers

    private func makeInMemoryStore() throws -> ReceiptStore {
        let container = try ModelContainer(
            for: ReceiptEntity.self, ReceiptItemEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ReceiptStore(modelContext: ModelContext(container))
    }

    private func makeInMemoryProductStore() throws -> ProductStore {
        let container = try ModelContainer(
            for: ProductEntity.self, PurchaseEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ProductStore(modelContext: ModelContext(container))
    }

    @Test func sampleDataIsPopulated() {
        #expect(!SampleData.receipts.isEmpty)
        #expect(SampleData.receipts.allSatisfy { $0.totalAmount > 0 })
    }

    @Test func krwFormattingUsesWonSymbolWithNoDecimals() {
        let amount = Decimal(12500)
        #expect(amount.formatted(as: .krw) == "₩12,500")
    }

    @Test func receiptItemComputesTotalPrice() {
        let item = ReceiptItem(name: "Latte", quantity: 2, unitPrice: 4500)
        #expect(item.totalPrice == 9000)
    }

    @Test func homeSummaryComputesPercentChange() {
        let calendar = Calendar.current
        let now = Date.now
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let current = Receipt(merchantName: "Test", date: now, totalAmount: 150, category: .other, paymentMethod: .card)
        let previous = Receipt(merchantName: "Test", date: lastMonth, totalAmount: 100, category: .other, paymentMethod: .card)

        let summary = HomeSummary.make(from: [current, previous], calendar: calendar, referenceDate: now)

        #expect(summary.currentMonthTotal == 150)
        #expect(summary.previousMonthTotal == 100)
        #expect(summary.percentChange == 50)
    }

    @Test func homeSummaryHasNilPercentChangeWithoutPreviousMonth() {
        let now = Date.now
        let receipt = Receipt(merchantName: "Test", date: now, totalAmount: 100, category: .other, paymentMethod: .card)
        let summary = HomeSummary.make(from: [receipt], referenceDate: now)
        #expect(summary.percentChange == nil)
    }

    // MARK: - SwiftData persistence

    @Test func addedReceiptPersistsAcrossStoreReloads() throws {
        let container = try ModelContainer(
            for: ReceiptEntity.self, ReceiptItemEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let firstStore = ReceiptStore(modelContext: ModelContext(container))
        let receipt = Receipt(
            merchantName: "Test Cafe",
            date: .now,
            totalAmount: 5000,
            category: .cafe,
            paymentMethod: .card,
            items: [ReceiptItem(name: "Latte", unitPrice: 5000)]
        )
        firstStore.add(receipt)

        // A second store backed by a fresh ModelContext on the same
        // container simulates reading the persistent store after relaunch.
        let secondStore = ReceiptStore(modelContext: ModelContext(container))
        let reloaded = secondStore.receipts.first { $0.id == receipt.id }
        #expect(reloaded?.merchantName == "Test Cafe")
        #expect(reloaded?.totalAmount == 5000)
        #expect(reloaded?.items.map(\.name) == ["Latte"])
    }

    @Test func seedSampleDataOnlyRunsOnceWhenStoreIsEmpty() throws {
        let store = try makeInMemoryStore()
        #expect(store.receipts.isEmpty)

        store.seedSampleDataIfNeeded()
        #expect(store.receipts.count == SampleData.receipts.count)

        store.seedSampleDataIfNeeded()
        #expect(store.receipts.count == SampleData.receipts.count)
    }

    @Test func updateReceiptChangesFieldsAndItems() throws {
        let store = try makeInMemoryStore()
        let original = Receipt(
            merchantName: "Old Name",
            date: .now,
            totalAmount: 1000,
            category: .other,
            paymentMethod: .cash,
            items: [ReceiptItem(name: "A", unitPrice: 1000)]
        )
        store.add(original)

        var updated = original
        updated.merchantName = "New Name"
        updated.totalAmount = 2000
        updated.category = .shopping
        updated.items = [ReceiptItem(name: "B", unitPrice: 2000)]
        store.update(updated)

        let reloaded = store.receipts.first { $0.id == original.id }
        #expect(reloaded?.merchantName == "New Name")
        #expect(reloaded?.totalAmount == 2000)
        #expect(reloaded?.category == .shopping)
        #expect(reloaded?.items.map(\.name) == ["B"])
    }

    @Test func deleteReceiptRemovesItFromStore() throws {
        let store = try makeInMemoryStore()
        let receipt = Receipt(merchantName: "Delete Me", date: .now, totalAmount: 1000, category: .other, paymentMethod: .cash)
        store.add(receipt)
        #expect(store.receipts.contains { $0.id == receipt.id })

        store.delete(receipt)
        #expect(!store.receipts.contains { $0.id == receipt.id })
    }

    // MARK: - Search

    @Test func searchFiltersByMerchantItemAndCategory() {
        let receipts = [
            Receipt(
                merchantName: "Starbucks",
                date: .now,
                totalAmount: 6800,
                category: .cafe,
                paymentMethod: .card,
                items: [ReceiptItem(name: "Caffe Latte", unitPrice: 6800)]
            ),
            Receipt(
                merchantName: "CU",
                date: .now,
                totalAmount: 3000,
                category: .grocery,
                paymentMethod: .cash,
                items: [ReceiptItem(name: "Pepsi", unitPrice: 3000)]
            )
        ]

        #expect(ReceiptSearch.filter(receipts, query: "starbucks").count == 1)
        #expect(ReceiptSearch.filter(receipts, query: "pepsi").count == 1)
        #expect(ReceiptSearch.filter(receipts, query: SpendingCategory.grocery.displayName).count == 1)
        #expect(ReceiptSearch.filter(receipts, query: "").count == 2)
        #expect(ReceiptSearch.filter(receipts, query: "nonexistent").isEmpty)
    }

    // MARK: - Grouping

    @Test func groupsReceiptsByMonthWithRelativeLabels() {
        let calendar = Calendar.current
        let now = Date.now
        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!

        let thisMonth = Receipt(merchantName: "A", date: now, totalAmount: 100, category: .other, paymentMethod: .card)
        let lastMonth = Receipt(merchantName: "B", date: lastMonthDate, totalAmount: 200, category: .other, paymentMethod: .card)

        let groups = ReceiptGrouping.byMonth([thisMonth, lastMonth], calendar: calendar, referenceDate: now)

        #expect(groups.count == 2)
        #expect(groups[0].title == String(localized: "이번 달"))
        #expect(groups[0].receipts.map(\.merchantName) == ["A"])
        #expect(groups[1].title == String(localized: "지난달"))
        #expect(groups[1].receipts.map(\.merchantName) == ["B"])
    }

    // MARK: - Manual entry parsing

    @Test func draftParserParsesAmountsAndQuantities() {
        #expect(ReceiptDraftParser.parseAmount("12500") == 12500)
        #expect(ReceiptDraftParser.parseAmount("  ") == nil)
        #expect(ReceiptDraftParser.parseAmount("") == nil)
        #expect(ReceiptDraftParser.parseQuantity("3") == 3)
        #expect(ReceiptDraftParser.parseQuantity("") == 1)
        #expect(ReceiptDraftParser.parseQuantity("0") == 1)
    }

    // MARK: - Analytics over persisted data

    @Test func analyticsSummaryReflectsStoreReceipts() throws {
        let store = try makeInMemoryStore()
        store.add(Receipt(merchantName: "Test", date: .now, totalAmount: 12345, category: .food, paymentMethod: .card))

        let summary = AnalyticsSummary.make(from: store.receipts)
        #expect(summary.totalSpent == 12345)
    }

    // MARK: - OCR: text normalization / field extraction

    @Test func parsesKoreanCafeReceipt() throws {
        let draft = ReceiptParser.parse(lines: [
            "스타벅스 강남점",
            "서울특별시 강남구",
            "TEL 02-1234-5678",
            "2026-09-10 14:32",
            "아메리카노 T          5,500",
            "합계                  5,500",
            "카드결제"
        ])

        #expect(draft.merchantName == "스타벅스 강남점")
        #expect(draft.total == 5500)
        #expect(draft.paymentMethod == .card)
        #expect(draft.category == .cafe)
        #expect(draft.items.map(\.name) == ["아메리카노 T"])
        #expect(draft.items.map(\.unitPrice) == [5500])

        let components = Calendar.current.dateComponents([.year, .month, .day], from: try #require(draft.date))
        #expect(components.year == 2026 && components.month == 9 && components.day == 10)
        #expect(!draft.lowConfidenceFields.contains(.total))
        #expect(!draft.lowConfidenceFields.contains(.merchant))
    }

    @Test func parsesConvenienceStoreReceiptWithMultipleItems() {
        let draft = ReceiptParser.parse(lines: [
            "CU 신촌점",
            "2026-09-08",
            "생수 500ml        1,500",
            "새우깡              1,200",
            "합계                2,700",
            "현금"
        ])

        #expect(draft.merchantName == "CU 신촌점")
        #expect(draft.total == 2700)
        #expect(draft.paymentMethod == .cash)
        #expect(draft.category == .grocery)
        #expect(draft.items.count == 2)
        #expect(draft.items.map(\.unitPrice) == [1500, 1200])
        #expect(!draft.lowConfidenceFields.contains(.total))
    }

    @Test func parsesEnglishMixedReceipt() {
        let draft = ReceiptParser.parse(lines: [
            "STARBUCKS COFFEE",
            "2026-09-01",
            "Americano Tall          5500",
            "Total                   5500",
            "CARD"
        ])

        #expect(draft.merchantName == "STARBUCKS COFFEE")
        #expect(draft.total == 5500)
        #expect(draft.paymentMethod == .card)
        #expect(draft.category == .cafe)
        #expect(draft.items.map(\.name) == ["Americano Tall"])
    }

    @Test func parsesReceiptWhereOnlyTotalIsUnambiguous() {
        let draft = ReceiptParser.parse(lines: [
            "GS25",
            "아메리카노              4500",
            "빵                    3000",
            "결제금액                7500",
            "카드"
        ])

        #expect(draft.total == 7500)
        #expect(!draft.lowConfidenceFields.contains(.total))
        // No date line at all anywhere in this receipt — date should be
        // reported as low-confidence rather than guessed.
        #expect(draft.date == nil)
        #expect(draft.lowConfidenceFields.contains(.date))
    }

    @Test func handlesPartiallyMissingOrGarbledOCR() {
        let draft = ReceiptParser.parse(lines: [
            "///////",
            "12:45",
            "결제금액 15,000"
        ])

        #expect(draft.merchantName == nil)
        #expect(draft.date == nil)
        #expect(draft.total == 15000)
        #expect(draft.items.isEmpty)
        #expect(draft.lowConfidenceFields.contains(.merchant))
        #expect(draft.lowConfidenceFields.contains(.date))
        #expect(draft.needsReview)
    }

    @Test func emptyOCROutputProducesAFullyLowConfidenceDraft() {
        let draft = ReceiptParser.parse(lines: [])
        #expect(draft.merchantName == nil)
        #expect(draft.total == nil)
        #expect(draft.items.isEmpty)
        #expect(draft.needsReview)
    }

    @Test func normalizationDropsBlankAndWhitespaceOnlyLines() {
        let draft = ReceiptParser.parse(lines: ["  ", "", "GS25", "\n", "결제금액 1,000"])
        #expect(draft.merchantName == "GS25")
        #expect(draft.total == 1000)
    }

    @Test func normalizationCollapsesConsecutiveDuplicateOCRLines() {
        // Vision sometimes double-emits a line (overlapping observations of
        // the same text). Consecutive duplicates shouldn't double-count an
        // item or inflate the parsed total.
        let draft = ReceiptParser.parse(lines: [
            "CU 신촌점",
            "CU 신촌점",
            "생수 500ml        1,500",
            "생수 500ml        1,500",
            "합계                1,500",
            "합계                1,500"
        ])

        #expect(draft.merchantName == "CU 신촌점")
        #expect(draft.total == 1500)
        #expect(draft.items.count == 1)
    }

    // MARK: - ReceiptDraft -> Receipt conversion

    @Test func draftConvertsToReceiptFillingGapsWithNeutralDefaults() {
        let draft = ReceiptDraft(
            merchantName: nil,
            date: nil,
            total: nil,
            items: [ReceiptItem(name: "Item", unitPrice: 1000)],
            paymentMethod: nil,
            category: nil,
            lowConfidenceFields: [.merchant, .date, .total]
        )
        let fallback = Date.now
        let receipt = draft.asReceipt(fallbackDate: fallback)

        #expect(receipt.merchantName.isEmpty)
        #expect(receipt.date == fallback)
        #expect(receipt.totalAmount == 1000) // falls back to summing items
        #expect(receipt.category == .other)
        #expect(receipt.paymentMethod == .card)
    }

    @Test func draftConvertsToReceiptPreservingConfidentFields() {
        let draft = ReceiptDraft(
            merchantName: "Starbucks",
            date: Date(timeIntervalSince1970: 0),
            total: 5500,
            items: [ReceiptItem(name: "Latte", unitPrice: 5500)],
            paymentMethod: .card,
            category: .cafe,
            lowConfidenceFields: []
        )
        let receipt = draft.asReceipt()

        #expect(receipt.merchantName == "Starbucks")
        #expect(receipt.date == Date(timeIntervalSince1970: 0))
        #expect(receipt.totalAmount == 5500)
        #expect(receipt.category == .cafe)
        #expect(receipt.paymentMethod == .card)
        #expect(!draft.needsReview)
    }

    // MARK: - OCR -> save regression (draft flows through the same ReceiptStore seam)

    @Test func reviewedDraftSavesThroughTheSameStoreSeamAsManualEntry() throws {
        let store = try makeInMemoryStore()
        let draft = ReceiptParser.parse(lines: [
            "스타벅스 강남점",
            "2026-09-10",
            "아메리카노 T          5,500",
            "합계                  5,500",
            "카드결제"
        ])

        store.add(draft.asReceipt())

        let saved = try #require(store.receipts.first)
        #expect(saved.merchantName == "스타벅스 강남점")
        #expect(saved.totalAmount == 5500)
        #expect(saved.items.map(\.name) == ["아메리카노 T"])
    }

    // MARK: - Scan state machine regression

    @Test func scanViewModelReachesFailedStateWhenNoTextIsFound() async {
        let viewModel = ScanViewModel()
        let blankImage = Self.makeSolidImage(size: CGSize(width: 200, height: 200))
        viewModel.process(image: blankImage)

        // Allow the async OCR pipeline to run to completion. Vision's
        // .accurate recognizer can take several seconds on a cold start
        // in the simulator, so this is generous on purpose.
        for _ in 0..<150 {
            if viewModel.state != .capturing, viewModel.state != .processing { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        #expect(viewModel.state == .failed(.noTextFound))
    }

    @Test func scanViewModelReachesReviewStateForARecognizableReceiptPhoto() async throws {
        let viewModel = ScanViewModel()
        let image = Self.makeSyntheticReceiptImage(lines: ["STARBUCKS", "2026-09-10", "Latte 5500", "Total 5500"])
        viewModel.process(image: image)

        for _ in 0..<150 {
            if viewModel.state != .capturing, viewModel.state != .processing { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard case .review(let draft) = viewModel.state else {
            Issue.record("Expected .review, got \(viewModel.state)")
            return
        }
        #expect(!draft.items.isEmpty || draft.total != nil)
    }

    // MARK: - Product

    @Test func productLookupByBarcodeFindsCreatedProduct() throws {
        let store = try makeInMemoryProductStore()
        let created = store.createProduct(Product(barcode: "8801234567890", name: "테스트 상품"))

        let found = store.product(forBarcode: "8801234567890")
        #expect(found?.id == created.id)
        #expect(found?.name == "테스트 상품")
    }

    @Test func productLookupNormalizesSurroundingWhitespaceInBarcode() throws {
        let store = try makeInMemoryProductStore()
        store.createProduct(Product(barcode: "8801234567890", name: "테스트 상품"))

        #expect(store.product(forBarcode: "  8801234567890  ") != nil)
    }

    @Test func productLookupRejectsEmptyBarcode() throws {
        let store = try makeInMemoryProductStore()
        store.createProduct(Product(barcode: "8801234567890", name: "테스트 상품"))

        #expect(store.product(forBarcode: "") == nil)
        #expect(store.product(forBarcode: "   ") == nil)
    }

    @Test func creatingProductWithDuplicateBarcodeReturnsExistingProductInstead() throws {
        let store = try makeInMemoryProductStore()
        let first = store.createProduct(Product(barcode: "8801234567890", name: "첫 번째 이름"))
        let second = store.createProduct(Product(barcode: "8801234567890", name: "두 번째 이름"))

        #expect(first.id == second.id)
        #expect(store.products.count == 1)
        #expect(store.products.first?.name == "첫 번째 이름")
    }

    @Test func createProductPersistsAllFields() throws {
        let store = try makeInMemoryProductStore()
        let product = store.createProduct(Product(
            barcode: "8801234567890",
            name: "펩시 제로",
            brand: "펩시",
            category: .grocery,
            unit: "355ml"
        ))

        #expect(product.name == "펩시 제로")
        #expect(product.brand == "펩시")
        #expect(product.category == .grocery)
        #expect(product.unit == "355ml")
    }

    @Test func updateProductChangesFieldsButKeepsBarcodeAndIdentity() throws {
        let store = try makeInMemoryProductStore()
        let created = store.createProduct(Product(barcode: "8801234567890", name: "Old Name"))

        var updated = created
        updated.name = "New Name"
        updated.brand = "New Brand"
        store.updateProduct(updated)

        let reloaded = store.products.first { $0.id == created.id }
        #expect(reloaded?.name == "New Name")
        #expect(reloaded?.brand == "New Brand")
        #expect(reloaded?.barcode == "8801234567890")
    }

    // MARK: - Purchase

    @Test func addPurchaseLinksToProductAndPersistsPriceAndQuantity() throws {
        let store = try makeInMemoryProductStore()
        let product = store.createProduct(Product(barcode: "8801234567890", name: "테스트 상품"))
        store.addPurchase(Purchase(productID: product.id, price: 1800, quantity: 2, storeName: "CU"))

        let purchases = store.purchases(forProduct: product.id)
        #expect(purchases.count == 1)
        #expect(purchases.first?.price == 1800)
        #expect(purchases.first?.quantity == 2)
        #expect(purchases.first?.storeName == "CU")
    }

    @Test func addPurchaseLinksToReceiptWhenProvided() throws {
        let store = try makeInMemoryProductStore()
        let product = store.createProduct(Product(barcode: "8801234567890", name: "테스트 상품"))
        let receiptID = UUID()
        store.addPurchase(Purchase(productID: product.id, price: 1500, receiptID: receiptID))

        #expect(store.purchases(forProduct: product.id).first?.receiptID == receiptID)
    }

    @Test func addPurchaseForUnknownProductIsANoOp() throws {
        let store = try makeInMemoryProductStore()
        let result = store.addPurchase(Purchase(productID: UUID(), price: 1000))

        #expect(result == nil)
        #expect(store.purchases.isEmpty)
    }

    // MARK: - Product matching (ReceiptItem -> Product)

    @Test func productMatcherFindsUnambiguousNameMatch() {
        let products = [Product(barcode: "8801234567890", name: "펩시 제로")]
        let match = ProductMatcher.match(itemName: "펩시 제로", existingProducts: products)
        #expect(match?.name == "펩시 제로")
    }

    @Test func productMatcherIgnoresCaseAndSurroundingWhitespaceDifferences() {
        let products = [Product(barcode: "8801234567890", name: "Pepsi Zero")]
        let match = ProductMatcher.match(itemName: "  pepsi   zero  ", existingProducts: products)
        #expect(match?.name == "Pepsi Zero")
    }

    @Test func productMatcherReturnsNilWhenNoProductMatches() {
        let products = [Product(barcode: "8801234567890", name: "펩시 제로")]
        #expect(ProductMatcher.match(itemName: "아메리카노", existingProducts: products) == nil)
    }

    @Test func productMatcherReturnsNilForEmptyItemName() {
        let products = [Product(barcode: "8801234567890", name: "펩시 제로")]
        #expect(ProductMatcher.match(itemName: "   ", existingProducts: products) == nil)
    }

    @Test func productMatcherBacksOffWhenMultipleProductsShareANormalizedName() {
        // Ambiguous — guessing which one risks attaching a purchase (and its
        // price history) to the wrong product, so this must return nil
        // rather than picking either.
        let products = [
            Product(barcode: "8801234567890", name: "물티슈", brand: "브랜드 A"),
            Product(barcode: "8801234567891", name: "물티슈", brand: "브랜드 B")
        ]
        #expect(ProductMatcher.match(itemName: "물티슈", existingProducts: products) == nil)
    }

    // MARK: - Receipt -> Product linking

    @Test func receiptProductLinkerSetsProductIDOnlyForConfidentMatches() {
        let known = Product(barcode: "8801234567890", name: "제주삼다수")
        let receipt = Receipt(
            merchantName: "CU",
            date: .now,
            totalAmount: 2400,
            category: .grocery,
            paymentMethod: .cash,
            items: [
                ReceiptItem(name: "제주삼다수", unitPrice: 900),
                ReceiptItem(name: "이름 모를 간식", unitPrice: 1500)
            ]
        )

        let linked = ReceiptProductLinker.linkedReceipt(receipt, existingProducts: [known])

        #expect(linked.items[0].productID == known.id)
        #expect(linked.items[1].productID == nil)
        // Never invents a new product for the unmatched item.
        #expect(linked.items.count == receipt.items.count)
    }

    // MARK: - Receipt -> Purchase sync (Price History integration)

    @Test func syncPurchasesRecordsAPurchaseForEachLinkedItem() throws {
        let productStore = try makeInMemoryProductStore()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "제주삼다수"))

        let receipt = Receipt(
            merchantName: "CU 신촌점",
            date: Date(timeIntervalSince1970: 1_000_000),
            totalAmount: 900,
            category: .grocery,
            paymentMethod: .cash,
            items: [ReceiptItem(name: "제주삼다수", quantity: 2, unitPrice: 900)]
        )
        let linked = ReceiptProductLinker.linkedReceipt(receipt, existingProducts: productStore.products)

        productStore.syncPurchases(for: linked)

        let purchases = productStore.purchases(forProduct: product.id)
        #expect(purchases.count == 1)
        #expect(purchases.first?.price == 900)
        #expect(purchases.first?.quantity == 2)
        #expect(purchases.first?.storeName == "CU 신촌점")
        #expect(purchases.first?.receiptID == receipt.id)
        #expect(purchases.first?.purchasedAt == receipt.date)
    }

    @Test func syncPurchasesCreatesNothingForUnmatchedItemsAndNeverCreatesAProduct() throws {
        let productStore = try makeInMemoryProductStore()
        let receipt = Receipt(
            merchantName: "GS25",
            date: .now,
            totalAmount: 1500,
            category: .grocery,
            paymentMethod: .cash,
            items: [ReceiptItem(name: "처음 보는 상품", unitPrice: 1500)]
        )
        let linked = ReceiptProductLinker.linkedReceipt(receipt, existingProducts: productStore.products)

        productStore.syncPurchases(for: linked)

        #expect(productStore.products.isEmpty)
        #expect(productStore.purchases.isEmpty)
    }

    @Test func syncPurchasesIsIdempotentAcrossResavesOfTheSameReceipt() throws {
        let productStore = try makeInMemoryProductStore()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "신라면"))
        let receiptID = UUID()

        func linkedReceipt(price: Decimal) -> Receipt {
            ReceiptProductLinker.linkedReceipt(
                Receipt(
                    id: receiptID,
                    merchantName: "GS25",
                    date: .now,
                    totalAmount: price,
                    category: .grocery,
                    paymentMethod: .cash,
                    items: [ReceiptItem(name: "신라면", unitPrice: price)]
                ),
                existingProducts: productStore.products
            )
        }

        productStore.syncPurchases(for: linkedReceipt(price: 1200))
        productStore.syncPurchases(for: linkedReceipt(price: 1200)) // re-saving, unchanged
        #expect(productStore.purchases(forProduct: product.id).count == 1)

        productStore.syncPurchases(for: linkedReceipt(price: 1300)) // re-saving, price edited
        let purchases = productStore.purchases(forProduct: product.id)
        #expect(purchases.count == 1)
        #expect(purchases.first?.price == 1300)
    }

    @Test func deletePurchasesForReceiptRemovesOnlyThoseTiedToThatReceipt() throws {
        let productStore = try makeInMemoryProductStore()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "새우깡"))
        let keepReceiptID = UUID()
        let removeReceiptID = UUID()
        productStore.addPurchase(Purchase(productID: product.id, price: 1500, receiptID: keepReceiptID))
        productStore.addPurchase(Purchase(productID: product.id, price: 1500, receiptID: removeReceiptID))

        productStore.deletePurchases(forReceipt: removeReceiptID)

        let remaining = productStore.purchases(forProduct: product.id)
        #expect(remaining.count == 1)
        #expect(remaining.first?.receiptID == keepReceiptID)
    }

    @Test func deletingAReceiptCleansUpItsLinkedPurchases() throws {
        // Exercises ProductStore.deletePurchases(forReceipt:) directly,
        // called the same way ReceiptStore's onReceiptDeleted hook calls it
        // (see makeWiredStores() below for the hook itself).
        let receiptStore = try makeInMemoryStore()
        let productStore = try makeInMemoryProductStore()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "코카콜라 제로"))

        let receipt = Receipt(
            merchantName: "세븐일레븐",
            date: .now,
            totalAmount: 1900,
            category: .grocery,
            paymentMethod: .card,
            items: [ReceiptItem(name: "코카콜라 제로", unitPrice: 1900)]
        )
        let linked = ReceiptProductLinker.linkedReceipt(receipt, existingProducts: productStore.products)
        receiptStore.add(linked)
        productStore.syncPurchases(for: linked)
        #expect(productStore.purchases(forProduct: product.id).count == 1)

        receiptStore.delete(linked)
        productStore.deletePurchases(forReceipt: linked.id)

        #expect(!receiptStore.receipts.contains { $0.id == linked.id })
        #expect(productStore.purchases(forProduct: product.id).isEmpty)
    }

    @Test func deletingAProductCascadesDeleteOfItsPurchases() throws {
        let productStore = try makeInMemoryProductStore()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "새우깡"))
        productStore.addPurchase(Purchase(productID: product.id, price: 1500))
        #expect(productStore.purchases(forProduct: product.id).count == 1)

        productStore.deleteProduct(product)

        #expect(productStore.products.isEmpty)
        #expect(productStore.purchases(forProduct: product.id).isEmpty)
    }

    // MARK: - Receipt deletion cascade (P0-1 data integrity)
    //
    // These exercise ReceiptStore.onReceiptDeleted, the single hook
    // RootTabView wires to ProductStore.deletePurchases(forReceipt:) so no
    // UI call site has to remember to make two calls on delete. Every test
    // below calls only `receiptStore.delete(...)` — never ProductStore's
    // cleanup directly — to prove the wiring itself is what guarantees no
    // orphaned Purchase survives.

    /// Wires the two stores exactly the way RootTabView does, so these tests
    /// exercise the real cascade path rather than re-deriving it.
    private func makeWiredStores() throws -> (receiptStore: ReceiptStore, productStore: ProductStore) {
        let receiptStore = try makeInMemoryStore()
        let productStore = try makeInMemoryProductStore()
        receiptStore.onReceiptDeleted = { [productStore] receiptID in
            productStore.deletePurchases(forReceipt: receiptID)
        }
        return (receiptStore, productStore)
    }

    @Test func testA_deletingAReceiptRemovesItsLinkedPurchaseThroughTheHookAlone() throws {
        let (receiptStore, productStore) = try makeWiredStores()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "코카콜라 제로"))

        let receipt = Receipt(
            merchantName: "세븐일레븐",
            date: .now,
            totalAmount: 1900,
            category: .grocery,
            paymentMethod: .card,
            items: [ReceiptItem(name: "코카콜라 제로", unitPrice: 1900)]
        )
        let linked = ReceiptProductLinker.linkedReceipt(receipt, existingProducts: productStore.products)
        receiptStore.add(linked)
        productStore.syncPurchases(for: linked)
        #expect(productStore.purchases(forProduct: product.id).count == 1)

        // Only the receipt-store delete is called — no manual ProductStore cleanup.
        receiptStore.delete(linked)

        #expect(!receiptStore.receipts.contains { $0.id == linked.id })
        #expect(productStore.purchases(forProduct: product.id).isEmpty)
        #expect(productStore.receiptIDs(forProduct: product.id).isEmpty)
    }

    @Test func testB_editingAndResavingAReceiptDoesNotDuplicateItsPurchase() throws {
        let (receiptStore, productStore) = try makeWiredStores()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "신라면"))

        let original = Receipt(
            merchantName: "GS25",
            date: Date(timeIntervalSince1970: 1_000_000),
            totalAmount: 1200,
            category: .grocery,
            paymentMethod: .cash,
            items: [ReceiptItem(name: "신라면", unitPrice: 1200)]
        )
        let linkedOriginal = ReceiptProductLinker.linkedReceipt(original, existingProducts: productStore.products)
        receiptStore.add(linkedOriginal)
        productStore.syncPurchases(for: linkedOriginal)
        #expect(productStore.purchases(forProduct: product.id).count == 1)

        // Same flow as ManualReceiptEntryView's `.edit` save path: rebuild
        // the receipt with the same id and updated fields, re-link, update,
        // re-sync.
        let edited = Receipt(
            id: linkedOriginal.id,
            merchantName: linkedOriginal.merchantName,
            date: linkedOriginal.date,
            totalAmount: 1300,
            category: linkedOriginal.category,
            paymentMethod: linkedOriginal.paymentMethod,
            items: [ReceiptItem(name: "신라면", unitPrice: 1300)],
            createdAt: linkedOriginal.createdAt,
            updatedAt: .now
        )
        let linkedEdited = ReceiptProductLinker.linkedReceipt(edited, existingProducts: productStore.products)
        receiptStore.update(linkedEdited)
        productStore.syncPurchases(for: linkedEdited)

        #expect(receiptStore.receipts.count == 1)
        let purchases = productStore.purchases(forProduct: product.id)
        #expect(purchases.count == 1)
        #expect(purchases.first?.price == 1300)
    }

    @Test func testC_deletingAReceiptWithMultipleLinkedProductsRemovesAllOfThem() throws {
        let (receiptStore, productStore) = try makeWiredStores()
        let cola = productStore.createProduct(Product(barcode: "8801062971323", name: "코카콜라 제로"))
        let water = productStore.createProduct(Product(barcode: "8809598720013", name: "제주삼다수"))

        let receipt = Receipt(
            merchantName: "CU",
            date: .now,
            totalAmount: 2700,
            category: .grocery,
            paymentMethod: .card,
            items: [
                ReceiptItem(name: "코카콜라 제로", unitPrice: 1900),
                ReceiptItem(name: "제주삼다수", unitPrice: 800)
            ]
        )
        let linked = ReceiptProductLinker.linkedReceipt(receipt, existingProducts: productStore.products)
        receiptStore.add(linked)
        productStore.syncPurchases(for: linked)
        #expect(productStore.purchases(forProduct: cola.id).count == 1)
        #expect(productStore.purchases(forProduct: water.id).count == 1)

        receiptStore.delete(linked)

        #expect(productStore.purchases(forProduct: cola.id).isEmpty)
        #expect(productStore.purchases(forProduct: water.id).isEmpty)
    }

    @Test func testD_deletingAReceiptWithNoLinkedProductDeletesCleanly() throws {
        let (receiptStore, productStore) = try makeWiredStores()
        let receipt = Receipt(
            merchantName: "Kyobo Book Centre",
            date: .now,
            totalAmount: 21000,
            category: .other,
            paymentMethod: .card
        )
        receiptStore.add(receipt)
        #expect(receiptStore.receipts.count == 1)

        receiptStore.delete(receipt)

        #expect(receiptStore.receipts.isEmpty)
        #expect(productStore.purchases.isEmpty)
    }

    @Test func testE_deletingAReceiptDoesNotAffectPurchasesTiedToADifferentOrDanglingReceiptID() throws {
        let (receiptStore, productStore) = try makeWiredStores()
        let product = productStore.createProduct(Product(barcode: "8801121962045", name: "새우깡"))

        let keptReceipt = Receipt(
            merchantName: "GS25",
            date: .now,
            totalAmount: 1500,
            category: .grocery,
            paymentMethod: .cash,
            items: [ReceiptItem(name: "새우깡", unitPrice: 1500)]
        )
        let linkedKept = ReceiptProductLinker.linkedReceipt(keptReceipt, existingProducts: productStore.products)
        receiptStore.add(linkedKept)
        productStore.syncPurchases(for: linkedKept)

        // A purchase whose receiptID doesn't correspond to any Receipt that
        // ever existed in this store — e.g. leftover from a previous
        // install, or a future bug elsewhere. Deleting an unrelated,
        // real receipt must not touch it.
        let danglingReceiptID = UUID()
        productStore.addPurchase(Purchase(productID: product.id, price: 1500, receiptID: danglingReceiptID))
        #expect(productStore.purchases(forProduct: product.id).count == 2)

        let toDelete = Receipt(
            merchantName: "세븐일레븐",
            date: .now,
            totalAmount: 1600,
            category: .grocery,
            paymentMethod: .card,
            items: [ReceiptItem(name: "새우깡", unitPrice: 1600)]
        )
        let linkedToDelete = ReceiptProductLinker.linkedReceipt(toDelete, existingProducts: productStore.products)
        receiptStore.add(linkedToDelete)
        productStore.syncPurchases(for: linkedToDelete)
        #expect(productStore.purchases(forProduct: product.id).count == 3)

        receiptStore.delete(linkedToDelete)

        let remaining = productStore.purchases(forProduct: product.id)
        #expect(remaining.count == 2)
        #expect(remaining.contains { $0.receiptID == linkedKept.id })
        #expect(remaining.contains { $0.receiptID == danglingReceiptID })
        #expect(!remaining.contains { $0.receiptID == linkedToDelete.id })
    }

    @Test func analyticsAndPriceHistoryReflectOnlyRemainingDataAfterReceiptDeletion() throws {
        let (receiptStore, productStore) = try makeWiredStores()
        let cola = productStore.createProduct(Product(barcode: "8801062971323", name: "코카콜라 제로"))

        let cuReceipt = Receipt(
            merchantName: "CU 신촌점",
            date: .now,
            totalAmount: 1900,
            category: .grocery,
            paymentMethod: .card,
            items: [ReceiptItem(name: "코카콜라 제로", unitPrice: 1900)]
        )
        let linkedCU = ReceiptProductLinker.linkedReceipt(cuReceipt, existingProducts: productStore.products)
        receiptStore.add(linkedCU)
        productStore.syncPurchases(for: linkedCU)

        let gsReceipt = Receipt(
            merchantName: "GS25",
            date: .now,
            totalAmount: 6800,
            category: .cafe,
            paymentMethod: .card
        )
        receiptStore.add(gsReceipt)

        // Sanity check before deletion: both merchants show up, and the
        // product has one recorded purchase.
        #expect(StoreAnalytics.summarize(receiptStore.receipts).contains { $0.name == "CU 신촌점" })
        #expect(StoreAnalytics.summarize(receiptStore.receipts).contains { $0.name == "GS25" })
        #expect(PriceHistorySummary.make(from: productStore.purchases(forProduct: cola.id)).purchaseCount == 1)

        receiptStore.delete(linkedCU)

        let storesAfterDelete = StoreAnalytics.summarize(receiptStore.receipts)
        #expect(!storesAfterDelete.contains { $0.name == "CU 신촌점" })
        #expect(storesAfterDelete.contains { $0.name == "GS25" })

        let historyAfterDelete = PriceHistorySummary.make(from: productStore.purchases(forProduct: cola.id))
        #expect(historyAfterDelete.purchaseCount == 0)
        #expect(historyAfterDelete.recentPrice == nil)
    }

    // MARK: - Store analytics (Analytics "자주 찾은 상점")

    @Test func storeAnalyticsAggregatesVisitCountTotalSpentAndLastVisit() {
        let receipts = [
            Receipt(merchantName: "CU", date: Date(timeIntervalSince1970: 100), totalAmount: 1000, category: .grocery, paymentMethod: .cash),
            Receipt(merchantName: "CU", date: Date(timeIntervalSince1970: 300), totalAmount: 2000, category: .grocery, paymentMethod: .card),
            Receipt(merchantName: "Starbucks", date: Date(timeIntervalSince1970: 200), totalAmount: 6800, category: .cafe, paymentMethod: .card)
        ]

        let stores = StoreAnalytics.summarize(receipts)

        let cu = stores.first { $0.name == "CU" }
        #expect(cu?.visitCount == 2)
        #expect(cu?.totalSpent == 3000)
        #expect(cu?.lastVisit == Date(timeIntervalSince1970: 300))

        let starbucks = stores.first { $0.name == "Starbucks" }
        #expect(starbucks?.visitCount == 1)
        #expect(starbucks?.totalSpent == 6800)
    }

    @Test func storeAnalyticsIsCaseAndWhitespaceInsensitiveButKeepsDistinctBranchesSeparate() {
        let receipts = [
            Receipt(merchantName: "CU", date: daysAgoForTests(2), totalAmount: 1000, category: .grocery, paymentMethod: .cash),
            Receipt(merchantName: " cu ", date: daysAgoForTests(1), totalAmount: 1500, category: .grocery, paymentMethod: .cash),
            Receipt(merchantName: "CU 신촌점", date: daysAgoForTests(0), totalAmount: 2000, category: .grocery, paymentMethod: .cash)
        ]

        let stores = StoreAnalytics.summarize(receipts)

        // "CU" and " cu " merge (same normalized name); "CU 신촌점" is a
        // distinct branch name and must stay its own entry.
        #expect(stores.count == 2)
        let plainCU = stores.first { $0.name.lowercased() == "cu" }
        #expect(plainCU?.visitCount == 2)
        #expect(plainCU?.totalSpent == 2500)
        #expect(stores.contains { $0.name == "CU 신촌점" && $0.visitCount == 1 })
    }

    @Test func storeAnalyticsReturnsEmptyForNoReceipts() {
        #expect(StoreAnalytics.summarize([]).isEmpty)
    }

    private func daysAgoForTests(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
    }

    // MARK: - Price History

    @Test func priceHistorySummarizesRecentLowestHighestAndAverage() {
        let productID = UUID()
        let purchases = [
            Purchase(productID: productID, price: 1800, storeName: "CU", purchasedAt: Date(timeIntervalSince1970: 300)),
            Purchase(productID: productID, price: 1700, storeName: "GS25", purchasedAt: Date(timeIntervalSince1970: 200)),
            Purchase(productID: productID, price: 1900, storeName: "세븐일레븐", purchasedAt: Date(timeIntervalSince1970: 100))
        ]

        let summary = PriceHistorySummary.make(from: purchases)
        #expect(summary.recentPrice == 1800)
        #expect(summary.recentStoreName == "CU")
        #expect(summary.lowestPrice == 1700)
        #expect(summary.highestPrice == 1900)
        #expect(summary.averagePrice == 1800)
        #expect(summary.purchaseCount == 3)
        #expect(summary.sortedPurchases.map(\.price) == [1800, 1700, 1900])
    }

    @Test func priceHistoryOfNoPurchasesIsAllNil() {
        let summary = PriceHistorySummary.make(from: [])
        #expect(summary.recentPrice == nil)
        #expect(summary.lowestPrice == nil)
        #expect(summary.highestPrice == nil)
        #expect(summary.averagePrice == nil)
        #expect(summary.purchaseCount == 0)
    }

    // MARK: - Product search

    @Test func productSearchMatchesNameBrandBarcodeAndCategory() {
        let products = [
            Product(barcode: "8801062973792", name: "펩시 제로", brand: "펩시", category: .grocery),
            Product(barcode: "8809598720013", name: "제주삼다수", brand: "삼다수", category: .grocery)
        ]

        #expect(ProductSearch.filter(products, query: "Pepsi").isEmpty) // no English alias stored
        #expect(ProductSearch.filter(products, query: "펩시").count == 1)
        #expect(ProductSearch.filter(products, query: "880106").count == 1)
        #expect(ProductSearch.filter(products, query: "삼다수").count == 1)
        #expect(ProductSearch.filter(products, query: "").isEmpty)
    }

    // MARK: - Barcode

    @Test func barcodeNormalizationTrimsWhitespace() {
        #expect(Product.normalizeBarcode("  8801234567890  ") == "8801234567890")
    }

    @Test func barcodeScannerViewModelRejectsEmptyBarcode() throws {
        let productStore = try makeInMemoryProductStore()
        let viewModel = BarcodeScannerViewModel()

        viewModel.handle(barcode: "   ", productStore: productStore)
        #expect(viewModel.state == .scanning)
    }

    @Test func barcodeScannerViewModelFindsRegisteredProduct() async throws {
        let productStore = try makeInMemoryProductStore()
        let product = productStore.createProduct(Product(barcode: "8801234567890", name: "펩시 제로"))
        let viewModel = BarcodeScannerViewModel()

        viewModel.handle(barcode: "8801234567890", productStore: productStore)
        for _ in 0..<50 {
            if case .found = viewModel.state { break }
            try? await Task.sleep(for: .milliseconds(20))
        }

        guard case .found(let foundProduct) = viewModel.state else {
            Issue.record("Expected .found, got \(viewModel.state)")
            return
        }
        #expect(foundProduct.id == product.id)
    }

    @Test func barcodeScannerViewModelReportsNotFoundForUnknownBarcode() async throws {
        let productStore = try makeInMemoryProductStore()
        let viewModel = BarcodeScannerViewModel()

        viewModel.handle(barcode: "9999999999999", productStore: productStore)
        for _ in 0..<50 {
            if case .notFound = viewModel.state { break }
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(viewModel.state == .notFound(barcode: "9999999999999"))
    }

    @Test func barcodeScannerViewModelIgnoresRepeatedDetectionsOfTheSameCode() async throws {
        // The live camera feed calls handle() many times a second while a
        // code sits in frame — none of those repeats should re-trigger a
        // lookup once one is already in flight or resolved.
        let productStore = try makeInMemoryProductStore()
        productStore.createProduct(Product(barcode: "8801234567890", name: "테스트 상품"))
        let viewModel = BarcodeScannerViewModel()

        viewModel.handle(barcode: "8801234567890", productStore: productStore)
        for _ in 0..<50 {
            if case .found = viewModel.state { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        let stateAfterFirstLookup = viewModel.state

        viewModel.handle(barcode: "8801234567890", productStore: productStore)
        viewModel.handle(barcode: "8801234567890", productStore: productStore)
        #expect(viewModel.state == stateAfterFirstLookup)
    }

    // MARK: - Localization (barcode/product)

    /// Reads the compiled-from-source String Catalog directly rather than
    /// resolving `String(localized:)` at runtime — the test bundle doesn't
    /// carry the app target's compiled string tables (it hosts inside
    /// ReceiptBox.app, but `Bundle.main` resolution for a plain call site
    /// here isn't reliable across configurations), so this checks the
    /// artifact itself: every core barcode/product string exists as a key
    /// (i.e. has Korean text, the source language) with a non-empty English
    /// translation.
    @Test func coreProductStringsHaveEnglishTranslationsInTheCatalog() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ReceiptBox/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try #require(json?["strings"] as? [String: Any])

        let keys = [
            "바코드 스캔", "상품 등록", "가격 이력", "구매 기록", "최근 가격",
            "최근 구매처", "구매 횟수", "구매처", "구매일", "상품명", "브랜드"
        ]
        for key in keys {
            let entry = try #require(strings[key] as? [String: Any], "Missing catalog entry for \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any], "No localizations for \(key)")
            let en = try #require(localizations["en"] as? [String: Any], "No English translation for \(key)")
            let stringUnit = try #require(en["stringUnit"] as? [String: Any], "Malformed English entry for \(key)")
            let value = try #require(stringUnit["value"] as? String)
            #expect(!value.isEmpty, "Empty English translation for \(key)")
        }
    }

    // MARK: - Real Vision OCR (exercises the actual on-device recognizer, no camera needed)

    @Test func realVisionOCRRecognizesSyntheticReceiptText() async throws {
        let image = Self.makeSyntheticReceiptImage(lines: ["STARBUCKS", "2026-09-10", "Latte 5500", "Total 5500"])
        let cgImage = try #require(image.cgImage)

        let lines = try await ReceiptTextRecognizer.recognizeLines(in: cgImage)
        #expect(!lines.isEmpty)

        let joined = lines.joined(separator: " ").lowercased()
        #expect(joined.contains("starbucks") || joined.contains("total") || joined.contains("latte"))
    }

    // MARK: - Test image fixtures

    private static func makeSolidImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func makeSyntheticReceiptImage(lines: [String]) -> UIImage {
        let size = CGSize(width: 600, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .medium),
                .foregroundColor: UIColor.black
            ]

            var y: CGFloat = 40
            for line in lines {
                (line as NSString).draw(at: CGPoint(x: 30, y: y), withAttributes: attributes)
                y += 50
            }
        }
    }
}
