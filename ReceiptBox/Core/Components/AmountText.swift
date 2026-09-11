//
//  AmountText.swift
//  ReceiptBox
//

import SwiftUI

/// Displays a currency amount with the visual hierarchy appropriate to
/// its context (large hero amount, medium summary, or inline small).
struct AmountText: View {
    enum Style {
        case large, medium, small
    }

    let amount: Decimal
    let currency: Currency
    var style: Style = .large

    var body: some View {
        Text(amount.formatted(as: currency))
            .font(font)
            .foregroundStyle(Color.rbTextPrimary)
            .monospacedDigit()
    }

    private var font: Font {
        switch style {
        case .large: RBFont.largeAmount
        case .medium: RBFont.amount
        case .small: RBFont.headline
        }
    }
}
