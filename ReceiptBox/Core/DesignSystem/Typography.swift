//
//  Typography.swift
//  ReceiptBox
//

import SwiftUI

/// System-typography scale. All styles are Dynamic Type based so they
/// scale with the user's preferred text size.
enum RBFont {
    static let screenTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let largeAmount = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let amount = Font.system(.title2, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.system(.title3, design: .rounded).weight(.semibold)
    static let headline = Font.system(.headline)
    static let body = Font.system(.body)
    static let subheadline = Font.system(.subheadline)
    static let caption = Font.system(.caption)
}
