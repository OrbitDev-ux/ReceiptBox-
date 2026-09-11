//
//  ReceiptCard.swift
//  ReceiptBox
//

import SwiftUI

/// A polished, reusable card representing a single receipt in a list.
struct ReceiptCard: View {
    let receipt: Receipt
    var showsItemCount: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .fill(receipt.category.tint.opacity(0.15))
                    Image(systemName: receipt.category.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(receipt.category.tint)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(receipt.merchantName)
                        .font(RBFont.headline)
                        .foregroundStyle(Color.rbTextPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(RBFont.caption)
                        .foregroundStyle(Color.rbTextSecondary)
                }

                Spacer(minLength: Spacing.s)

                VStack(alignment: .trailing, spacing: 2) {
                    AmountText(amount: receipt.totalAmount, currency: receipt.currency, style: .small)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.rbTextTertiary)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(receipt.merchantName), \(receipt.formattedTotal), \(receipt.date.formatted(date: .abbreviated, time: .omitted))")
        .accessibilityAddTraits(.isButton)
    }

    private var subtitle: String {
        let dateString = receipt.date.formatted(date: .abbreviated, time: .omitted)
        guard showsItemCount, receipt.items.count > 0 else { return dateString }
        let itemsText = String(localized: "\(receipt.items.count)개 상품")
        // ^ Key carries the count as a plural-aware placeholder (see
        // Localizable.xcstrings): Korean has one invariant form, English
        // gets a one/other "item"/"items" split.
        return "\(dateString) · \(itemsText)"
    }
}
