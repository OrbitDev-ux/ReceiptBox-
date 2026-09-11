//
//  AnalyticsView.swift
//  ReceiptBox
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(ReceiptStore.self) private var store

    private var summary: AnalyticsSummary {
        AnalyticsSummary.make(from: store.receipts)
    }

    private var stores: [Store] {
        Array(StoreAnalytics.summarize(store.receipts).prefix(8))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    totalCard
                    trendSection
                    categorySection
                    topStoresSection
                }
                .padding(Spacing.m)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.rbBackground)
            .navigationTitle("분석")
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("총 지출")
                .font(RBFont.subheadline)
                .foregroundStyle(Color.rbTextSecondary)
            AmountText(amount: summary.totalSpent, currency: summary.currency, style: .large)
            Text(lastMonthsText)
                .font(RBFont.caption)
                .foregroundStyle(Color.rbTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Spacing.l)
    }

    private var lastMonthsText: String {
        let prefix = String(localized: "최근")
        let suffix = String(localized: "개월")
        return "\(prefix) \(summary.monthlyTrend.count)\(suffix)"
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "월별 지출")

            Chart(summary.monthlyTrend) { point in
                BarMark(
                    x: .value("Month", point.date, unit: .month),
                    y: .value("Total", NSDecimalNumber(decimal: point.total).doubleValue)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis(.hidden)
            .accessibilityLabel("월별 지출 추이")
            .accessibilityValue(monthlyTrendAccessibilitySummary)
        }
        .cardStyle()
    }

    private var monthlyTrendAccessibilitySummary: String {
        summary.monthlyTrend
            .map { "\($0.date.formatted(.dateTime.month(.abbreviated))) \($0.total.formatted(as: summary.currency))" }
            .joined(separator: ", ")
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "카테고리별")

            Chart(summary.categoryTotals) { item in
                SectorMark(
                    angle: .value("Amount", NSDecimalNumber(decimal: item.amount).doubleValue),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(item.category.tint)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .accessibilityLabel("카테고리별 지출")
            .accessibilityValue(categoryAccessibilitySummary)

            VStack(spacing: Spacing.s) {
                ForEach(summary.categoryTotals) { item in
                    HStack {
                        Circle().fill(item.category.tint).frame(width: 8, height: 8)
                        Text(item.category.displayName)
                            .font(RBFont.subheadline)
                            .foregroundStyle(Color.rbTextPrimary)
                        Spacer()
                        Text(item.amount.formatted(as: summary.currency))
                            .font(RBFont.subheadline.weight(.medium))
                            .foregroundStyle(Color.rbTextSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, Spacing.xs)
        }
        .cardStyle()
    }

    private var categoryAccessibilitySummary: String {
        summary.categoryTotals
            .map { "\($0.category.displayName) \($0.amount.formatted(as: summary.currency))" }
            .joined(separator: ", ")
    }

    private var topStoresSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "자주 찾은 상점")

            VStack(spacing: Spacing.s) {
                ForEach(stores) { store in
                    HStack(spacing: Spacing.m) {
                        ZStack {
                            Circle().fill(store.category.tint.opacity(0.15))
                            Image(systemName: store.category.symbolName)
                                .foregroundStyle(store.category.tint)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.name)
                                .font(RBFont.body)
                                .foregroundStyle(Color.rbTextPrimary)
                            Text(visitsText(for: store))
                                .font(RBFont.caption)
                                .foregroundStyle(Color.rbTextSecondary)
                        }

                        Spacer()

                        Text(store.totalSpent.formatted(as: .krw))
                            .font(RBFont.subheadline.weight(.medium))
                            .foregroundStyle(Color.rbTextPrimary)
                    }
                    .padding(.vertical, Spacing.xs)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardStyle()
    }

    private func visitsText(for store: Store) -> String {
        let suffix = String(localized: "회 방문")
        return "\(store.visitCount)\(suffix)"
    }
}

#Preview {
    AnalyticsView()
        .environment(ReceiptStore.preview())
}
