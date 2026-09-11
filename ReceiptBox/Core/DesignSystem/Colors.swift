//
//  Colors.swift
//  ReceiptBox
//

import SwiftUI

/// Semantic color palette built entirely on system colors so Light Mode,
/// Dark Mode, and contrast settings are respected automatically.
extension Color {
    static let rbBackground = Color(.systemGroupedBackground)
    static let rbSurface = Color(.secondarySystemGroupedBackground)
    static let rbSurfaceElevated = Color(.tertiarySystemGroupedBackground)

    static let rbTextPrimary = Color(.label)
    static let rbTextSecondary = Color(.secondaryLabel)
    static let rbTextTertiary = Color(.tertiaryLabel)

    static let rbPositive = Color(.systemGreen)
    static let rbNegative = Color(.systemRed)
}
