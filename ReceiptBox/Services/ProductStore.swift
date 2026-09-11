//
//  ProductStore.swift
//  ReceiptBox
//
//  The source of truth for products and purchases, mirroring ReceiptStore's
//  shape: plain domain arrays in memory, SwiftData underneath, nothing else
//  in the app touches a ModelContext directly. Deliberately a separate
//  store (and a separate ModelContext) from ReceiptStore — Product/Purchase
//  have no SwiftData relationship back to Receipt/ReceiptItem, only the
//  plain, unenforced `Purchase.receiptID` link, so there's no reason for
//  the two to share transactional state.
//
//  Product lookup today is purely local (`product(forBarcode:)` is a
//  synchronous fetch). If a remote product database is ever added, this is
//  the one place that would grow a fallback path — callers already treat
//  lookup as "may return nil", so nothing upstream would need to change.

import Foundation
import Observation
import SwiftData

@Observable
final class ProductStore {
    private(set) var products: [Product] = []
    private(set) var purchases: [Purchase] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    // MARK: - Seeding

    func seedSampleDataIfNeeded() {
        let descriptor = FetchDescriptor<ProductEntity>()
        guard (try? modelContext.fetchCount(descriptor)) == 0 else { return }

        var entityByProductID: [UUID: ProductEntity] = [:]
        for product in SampleData.products {
            let entity = ProductEntity(product: product)
            modelContext.insert(entity)
            entityByProductID[product.id] = entity
        }
        for purchase in SampleData.purchases {
            let entity = PurchaseEntity(purchase: purchase)
            entity.product = entityByProductID[purchase.productID]
            modelContext.insert(entity)
        }
        save()
        reload()
    }

    // MARK: - Lookup

    func product(forBarcode barcode: String) -> Product? {
        let normalized = Product.normalizeBarcode(barcode)
        guard !normalized.isEmpty else { return nil }
        var descriptor = FetchDescriptor<ProductEntity>(
            predicate: #Predicate<ProductEntity> { $0.barcode == normalized }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.asDomain
    }

    func purchases(forProduct productID: UUID) -> [Purchase] {
        purchases
            .filter { $0.productID == productID }
            .sorted { $0.purchasedAt > $1.purchasedAt }
    }

    // MARK: - Product mutations

    /// Creates a new product, unless a product with this barcode already
    /// exists — in which case the existing one is returned untouched. This
    /// is the one place barcode uniqueness is enforced; the entity's
    /// `.unique` attribute is a backstop, not the primary guard.
    @discardableResult
    func createProduct(_ product: Product) -> Product {
        let normalized = Product.normalizeBarcode(product.barcode)
        if let existing = self.product(forBarcode: normalized) {
            return existing
        }
        var toInsert = product
        toInsert.barcode = normalized
        modelContext.insert(ProductEntity(product: toInsert))
        save()
        reload()
        return toInsert
    }

    func updateProduct(_ product: Product) {
        guard let entity = fetchProductEntity(id: product.id) else { return }
        entity.updateScalarFields(from: product)
        save()
        reload()
    }

    func deleteProduct(_ product: Product) {
        guard let entity = fetchProductEntity(id: product.id) else { return }
        modelContext.delete(entity)
        save()
        reload()
    }

    // MARK: - Purchases

    @discardableResult
    func addPurchase(_ purchase: Purchase) -> Purchase? {
        guard let productEntity = fetchProductEntity(id: purchase.productID) else { return nil }
        let entity = PurchaseEntity(purchase: purchase)
        entity.product = productEntity
        modelContext.insert(entity)
        productEntity.updatedAt = .now
        save()
        reload()
        return purchase
    }

    // MARK: - Receipt reconciliation

    /// Records a Purchase for every item in `receipt` that's already linked
    /// to a Product (see `ReceiptProductLinker` — this trusts `item.productID`
    /// as-is and does not re-match by name), so a scanned or typed receipt
    /// feeds Price History the same way a barcode purchase does.
    ///
    /// Safe to call repeatedly for the same receipt — e.g. every time it's
    /// edited and re-saved: any purchases already tied to `receipt.id` are
    /// replaced rather than duplicated, since a plain scalar `receiptID`
    /// (not a SwiftData relationship) gives no other way to tell "this is
    /// the same purchase, just updated" from "this is a new one".
    func syncPurchases(for receipt: Receipt) {
        deletePurchases(forReceipt: receipt.id)

        for item in receipt.items {
            guard let productID = item.productID else { continue }
            addPurchase(Purchase(
                productID: productID,
                price: item.unitPrice,
                currency: receipt.currency,
                quantity: item.quantity,
                storeName: receipt.merchantName,
                purchasedAt: receipt.date,
                receiptID: receipt.id
            ))
        }
    }

    /// Removes every Purchase tied to `receiptID`. `Purchase.receiptID` is a
    /// plain, unenforced scalar rather than a SwiftData relationship (see
    /// the header comment on `Purchase`), so nothing cascades this
    /// automatically — callers that delete a Receipt are expected to call
    /// this too, so a deleted receipt doesn't leave orphaned purchases
    /// pointing at it.
    func deletePurchases(forReceipt receiptID: UUID) {
        let descriptor = FetchDescriptor<PurchaseEntity>(
            predicate: #Predicate<PurchaseEntity> { $0.receiptID == receiptID }
        )
        guard let entities = try? modelContext.fetch(descriptor), !entities.isEmpty else { return }
        for entity in entities {
            modelContext.delete(entity)
        }
        save()
        reload()
    }

    /// Every Receipt id with at least one Purchase recorded against
    /// `productID` — the seam `ProductDetailView` uses to show "관련 영수증"
    /// without ReceiptItem needing its own relationship back to Receipt.
    func receiptIDs(forProduct productID: UUID) -> Set<UUID> {
        Set(purchases(forProduct: productID).compactMap(\.receiptID))
    }

    // MARK: - Private

    private func fetchProductEntity(id: UUID) -> ProductEntity? {
        let targetID = id
        var descriptor = FetchDescriptor<ProductEntity>(
            predicate: #Predicate<ProductEntity> { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func reload() {
        let productDescriptor = FetchDescriptor<ProductEntity>(sortBy: [SortDescriptor(\.name)])
        products = ((try? modelContext.fetch(productDescriptor)) ?? []).map(\.asDomain)

        let purchaseDescriptor = FetchDescriptor<PurchaseEntity>(sortBy: [SortDescriptor(\.purchasedAt, order: .reverse)])
        purchases = ((try? modelContext.fetch(purchaseDescriptor)) ?? []).map(\.asDomain)
    }

    private func save() {
        try? modelContext.save()
    }
}

extension ProductStore {
    /// An in-memory store for previews and tests, pre-populated with
    /// `products`/`purchases` (defaults to the same sample data used on
    /// first launch).
    @MainActor
    static func preview(
        products: [Product] = SampleData.products,
        purchases: [Purchase] = SampleData.purchases
    ) -> ProductStore {
        let container = try! ModelContainer(
            for: ProductEntity.self, PurchaseEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        var entityByProductID: [UUID: ProductEntity] = [:]
        for product in products {
            let entity = ProductEntity(product: product)
            context.insert(entity)
            entityByProductID[product.id] = entity
        }
        for purchase in purchases {
            let entity = PurchaseEntity(purchase: purchase)
            entity.product = entityByProductID[purchase.productID]
            context.insert(entity)
        }
        try? context.save()
        return ProductStore(modelContext: context)
    }
}
