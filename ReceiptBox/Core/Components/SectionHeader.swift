//
//  SectionHeader.swift
//  ReceiptBox
//

import SwiftUI

/// A quiet section title, optionally with a trailing text action.
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var actionAccessibilityIdentifier: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(RBFont.sectionTitle)
                .foregroundStyle(Color.rbTextPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if let actionTitle, let action {
                Button(LocalizedStringKey(actionTitle), action: action)
                    .font(RBFont.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityIdentifier(actionAccessibilityIdentifier ?? "")
            }
        }
    }
}
