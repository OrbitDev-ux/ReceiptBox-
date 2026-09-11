//
//  SpendingSummaryCard.swift
//  ReceiptBox
//

import SwiftUI

/// The hero card on Home: this month's total with a prominent scan action
/// and a quiet comparison against last month.
struct SpendingSummaryCard: View {
    let summary: HomeSummary
    var onScanTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("이번 달")
                .font(RBFont.subheadline)
                .foregroundStyle(Color.rbTextSecondary)

            HStack(alignment: .top) {
                AmountText(amount: summary.currentMonthTotal, currency: summary.currency, style: .large)

                Spacer()

                Button(action: onScanTapped) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("영수증 추가")
                .accessibilityIdentifier("home.addReceiptButton")
            }

            if let percentChange = summary.percentChange {
                changeIndicator(percentChange)
            }
        }
        .cardStyle(padding: Spacing.l)
    }

    private func changeIndicator(_ percentChange: Double) -> some View {
        let isIncrease = percentChange >= 0
        let magnitude = abs(percentChange)
        let percentText = magnitude.formatted(.number.precision(.fractionLength(0)))
        let comparisonLabel = String(localized: "지난달 대비")
        let directionWord = String(localized: isIncrease ? "증가" : "감소")
        let displayText = "\(comparisonLabel) \(percentText)%"
        let accessibilityText = "\(comparisonLabel) \(percentText)% \(directionWord)"

        return HStack(spacing: Spacing.xs) {
            Image(systemName: isIncrease ? "arrow.up.right" : "arrow.down.right")
            Text(displayText)
        }
        .font(RBFont.caption.weight(.medium))
        .foregroundStyle(isIncrease ? Color.rbNegative : Color.rbPositive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

#Preview {
    SpendingSummaryCard(summary: .make(from: SampleData.receipts), onScanTapped: {})
        .padding()
}
