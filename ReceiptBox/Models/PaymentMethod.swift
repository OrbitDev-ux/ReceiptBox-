//
//  PaymentMethod.swift
//  ReceiptBox
//

import SwiftUI

nonisolated enum PaymentMethod: String, CaseIterable, Identifiable, Codable, Hashable {
    case card
    case cash
    case mobilePay
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .card: String(localized: "카드")
        case .cash: String(localized: "현금")
        case .mobilePay: String(localized: "모바일 결제")
        case .other: String(localized: "기타")
        }
    }

    var symbolName: String {
        switch self {
        case .card: "creditcard.fill"
        case .cash: "banknote.fill"
        case .mobilePay: "wave.3.right.circle.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .card: .blue
        case .cash: .green
        case .mobilePay: .purple
        case .other: .gray
        }
    }
}
