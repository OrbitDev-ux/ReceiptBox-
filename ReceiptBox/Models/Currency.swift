//
//  Currency.swift
//  ReceiptBox
//

import Foundation

nonisolated enum Currency: String, Codable, CaseIterable, Hashable {
    case krw = "KRW"
    case usd = "USD"

    var code: String { rawValue }
}
