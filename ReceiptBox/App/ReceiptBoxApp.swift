//
//  ReceiptBoxApp.swift
//  ReceiptBox
//

import SwiftUI
import SwiftData

@main
struct ReceiptBoxApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: ReceiptEntity.self, ReceiptItemEntity.self, ProductEntity.self, PurchaseEntity.self
            )
        } catch {
            fatalError("Failed to create ReceiptBox's persistent store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(modelContainer: modelContainer)
        }
    }
}
