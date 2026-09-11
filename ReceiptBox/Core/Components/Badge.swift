//
//  Badge.swift
//  ReceiptBox
//

import SwiftUI

/// A small pill used to surface category or payment-method metadata.
struct Badge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(RBFont.caption.weight(.medium))
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 6)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}

extension Badge {
    init(category: SpendingCategory) {
        self.init(title: category.displayName, systemImage: category.symbolName, tint: category.tint)
    }

    init(paymentMethod: PaymentMethod) {
        self.init(title: paymentMethod.displayName, systemImage: paymentMethod.symbolName, tint: paymentMethod.tint)
    }
}
