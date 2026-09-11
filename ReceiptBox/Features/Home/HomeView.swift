//
//  HomeView.swift
//  ReceiptBox
//

import SwiftUI

private enum HomeDestination: Hashable {
    case allReceipts
}

struct HomeView: View {
    var onScanTapped: () -> Void

    @Environment(ReceiptStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("rb.previewEmptyState") private var previewEmptyState = false
    @State private var path = NavigationPath()

    private var receipts: [Receipt] {
        previewEmptyState ? [] : store.receipts
    }

    private var summary: HomeSummary {
        HomeSummary.make(from: receipts)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header

                    if receipts.isEmpty {
                        EmptyStateView(
                            systemImage: "tray",
                            title: "아직 영수증이 없어요",
                            message: "영수증을 스캔하거나 추가하고 지출 관리를 시작해보세요.",
                            actionTitle: "영수증 추가",
                            action: onScanTapped
                        )
                        .padding(.top, Spacing.xl)
                    } else {
                        SpendingSummaryCard(summary: summary, onScanTapped: onScanTapped)

                        if !summary.categoryTotals.isEmpty {
                            CategoryOverviewSection(categoryTotals: summary.categoryTotals, currency: summary.currency)
                        }

                        recentReceiptsSection
                    }
                }
                .padding(.horizontal, Spacing.m)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.rbBackground)
            .toolbar(.hidden, for: .navigationBar)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: receipts)
            .navigationDestination(for: Receipt.self) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .allReceipts:
                    ReceiptsView(path: $path)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(greeting)
                .font(RBFont.subheadline)
                .foregroundStyle(Color.rbTextSecondary)
            Text("ReceiptBox")
                .font(RBFont.screenTitle)
                .foregroundStyle(Color.rbTextPrimary)
        }
        .padding(.top, Spacing.s)
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: String(localized: "좋은 아침이에요")
        case 12..<17: String(localized: "좋은 오후예요")
        default: String(localized: "좋은 저녁이에요")
        }
    }

    private var recentReceiptsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "최근 영수증", actionTitle: "모두 보기", actionAccessibilityIdentifier: "home.seeAllButton") {
                path.append(HomeDestination.allReceipts)
            }

            VStack(spacing: Spacing.s) {
                ForEach(summary.recentReceipts) { receipt in
                    ReceiptCard(receipt: receipt) {
                        path.append(receipt)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView(onScanTapped: {})
        .environment(ReceiptStore.preview())
        .environment(ProductStore.preview())
}
