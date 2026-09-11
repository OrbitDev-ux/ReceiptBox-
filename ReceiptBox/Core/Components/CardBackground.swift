//
//  CardBackground.swift
//  ReceiptBox
//

import SwiftUI

/// The shared card surface used across the app: rounded, subtly elevated,
/// and quiet rather than glassy.
struct CardBackground: ViewModifier {
    var padding: CGFloat = Spacing.m

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(Color.rbSurface)
            )
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.m) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
