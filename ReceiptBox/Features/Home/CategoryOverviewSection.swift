//
//  CategoryOverviewSection.swift
//  ReceiptBox
//

import SwiftUI

/// A quiet, at-a-glance breakdown of the top spending categories this month.
struct CategoryOverviewSection: View {
    let categoryTotals: [CategoryTotal]
    let currency: Currency

    private var topCategories: [CategoryTotal] {
        Array(categoryTotals.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "카테고리")

            HStack(spacing: Spacing.s) {
                ForEach(topCategories) { item in
                    VStack(spacing: Spacing.xs) {
                        ZStack {
                            Circle().fill(item.category.tint.opacity(0.15))
                            Image(systemName: item.category.symbolName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(item.category.tint)
                        }
                        .frame(width: 40, height: 40)

                        Text(item.category.displayName)
                            .font(RBFont.caption)
                            .foregroundStyle(Color.rbTextSecondary)
                            .lineLimit(1)

                        Text(item.amount.formatted(as: currency))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.rbTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardStyle()
    }
}

#Preview {
    CategoryOverviewSection(
        categoryTotals: HomeSummary.make(from: SampleData.receipts).categoryTotals,
        currency: .krw
    )
    .padding()
}
