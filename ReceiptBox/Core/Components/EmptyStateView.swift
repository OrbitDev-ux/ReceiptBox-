//
//  EmptyStateView.swift
//  ReceiptBox
//

import SwiftUI

/// A calm, centered empty state used for first-launch and filtered-empty
/// scenarios.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.rbTextTertiary)

            VStack(spacing: Spacing.xs) {
                Text(LocalizedStringKey(title))
                    .font(RBFont.headline)
                    .foregroundStyle(Color.rbTextPrimary)
                Text(LocalizedStringKey(message))
                    .font(RBFont.subheadline)
                    .foregroundStyle(Color.rbTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(LocalizedStringKey(actionTitle), action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
