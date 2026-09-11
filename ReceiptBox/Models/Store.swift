//
//  Store.swift
//  ReceiptBox
//

import Foundation

nonisolated struct Store: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: SpendingCategory
    var visitCount: Int
    var totalSpent: Decimal
    var lastVisit: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: SpendingCategory,
        visitCount: Int,
        totalSpent: Decimal,
        lastVisit: Date
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.visitCount = visitCount
        self.totalSpent = totalSpent
        self.lastVisit = lastVisit
    }
}
