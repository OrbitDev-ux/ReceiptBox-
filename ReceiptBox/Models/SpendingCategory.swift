//
//  SpendingCategory.swift
//  ReceiptBox
//

import SwiftUI

nonisolated enum SpendingCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case food
    case cafe
    case shopping
    case transport
    case grocery
    case health
    case entertainment
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: String(localized: "식비")
        case .cafe: String(localized: "카페")
        case .shopping: String(localized: "쇼핑")
        case .transport: String(localized: "교통")
        case .grocery: String(localized: "마트/편의점")
        case .health: String(localized: "건강")
        case .entertainment: String(localized: "여가")
        case .other: String(localized: "기타")
        }
    }

    var symbolName: String {
        switch self {
        case .food: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .shopping: "bag.fill"
        case .transport: "car.fill"
        case .grocery: "cart.fill"
        case .health: "heart.fill"
        case .entertainment: "film.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .food: .orange
        case .cafe: .brown
        case .shopping: .pink
        case .transport: .blue
        case .grocery: .green
        case .health: .red
        case .entertainment: .purple
        case .other: .gray
        }
    }
}
