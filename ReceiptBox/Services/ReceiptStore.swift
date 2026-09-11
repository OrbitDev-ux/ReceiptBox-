//
//  ReceiptStore.swift
//  ReceiptBox
//
//  The app's single source of truth for receipts, and the only place that
//  talks to SwiftData. Every screen reads `receipts` (plain Receipt
//  structs) and calls add/update/delete — none of them know a
//  ModelContext exists. Seeded with SampleData once, the first time the
//  persistent store is empty.

import Foundation
import Observation
import SwiftData

@Observable
final class ReceiptStore {
    private(set) var receipts: [Receipt] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    // MARK: - Seeding

    func seedSampleDataIfNeeded() {
        let descriptor = FetchDescriptor<ReceiptEntity>()
        guard (try? modelContext.fetchCount(descriptor)) == 0 else { return }
        for receipt in SampleData.receipts {
            modelContext.insert(ReceiptEntity(receipt: receipt))
        }
        save()
        reload()
    }

    // MARK: - Mutations

    func add(_ receipt: Receipt) {
        modelContext.insert(ReceiptEntity(receipt: receipt))
        save()
        reload()
    }

    func update(_ receipt: Receipt) {
        guard let entity = fetchEntity(id: receipt.id) else { return }

        entity.updateScalarFields(from: receipt)
        for oldItem in entity.items {
            modelContext.delete(oldItem)
        }
        entity.items = receipt.items.enumerated().map { index, item in
            ReceiptItemEntity(item: item, sortIndex: index)
        }

        save()
        reload()
    }

    func delete(_ receipt: Receipt) {
        delete(id: receipt.id)
    }

    func delete(id: UUID) {
        guard let entity = fetchEntity(id: id) else { return }
        modelContext.delete(entity)
        save()
        reload()
    }

    // MARK: - Private

    private func fetchEntity(id: UUID) -> ReceiptEntity? {
        let targetID = id
        var descriptor = FetchDescriptor<ReceiptEntity>(
            predicate: #Predicate<ReceiptEntity> { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func reload() {
        let descriptor = FetchDescriptor<ReceiptEntity>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        receipts = entities.map(\.asDomain)
    }

    private func save() {
        try? modelContext.save()
    }
}

extension ReceiptStore {
    /// An in-memory store for previews and tests, pre-populated with
    /// `seed` (defaults to the same sample data used on first launch).
    @MainActor
    static func preview(seed: [Receipt] = SampleData.receipts) -> ReceiptStore {
        let container = try! ModelContainer(
            for: ReceiptEntity.self, ReceiptItemEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        for receipt in seed {
            context.insert(ReceiptEntity(receipt: receipt))
        }
        try? context.save()
        return ReceiptStore(modelContext: context)
    }
}
