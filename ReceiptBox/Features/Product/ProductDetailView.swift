//
//  ProductDetailView.swift
//  ReceiptBox
//
//  A Product's identity plus everything derived from its purchase history.
//  Reached two ways: pushed from a plain NavigationStack (search results —
//  ordinary back button), or pushed inside the barcode "not found" flow
//  right after registering a new product, where `isPresentedModally` swaps
//  the back button for an explicit "완료" that closes the whole flow.

import Charts
import SwiftUI

struct ProductDetailView: View {
    let product: Product
    var isPresentedModally: Bool = false
    var onDone: (() -> Void)? = nil

    @Environment(ProductStore.self) private var productStore
    @Environment(ReceiptStore.self) private var receiptStore
    @State private var isShowingPurchaseEntry = false
    @State private var selectedReceipt: Receipt?

    private var purchases: [Purchase] {
        productStore.purchases(forProduct: product.id)
    }

    private var summary: PriceHistorySummary {
        PriceHistorySummary.make(from: purchases)
    }

    /// Receipts that produced a Purchase for this product — i.e. this
    /// product showed up as a matched line item on a scanned/typed receipt,
    /// not just a standalone barcode purchase (those leave `receiptID` nil).
    private var relatedReceipts: [Receipt] {
        let receiptIDs = productStore.receiptIDs(forProduct: product.id)
        guard !receiptIDs.isEmpty else { return [] }
        return receiptStore.receipts
            .filter { receiptIDs.contains($0.id) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header

                factsRow

                if summary.sortedPurchases.count > 1 {
                    priceChart
                }

                if !summary.sortedPurchases.isEmpty {
                    historySection
                }

                if !relatedReceipts.isEmpty {
                    relatedReceiptsSection
                }
            }
            .padding(Spacing.m)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.rbBackground)
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isPresentedModally)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { onDone?() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $isShowingPurchaseEntry) {
            PurchaseEntryView(product: product, defaultStoreName: summary.recentStoreName, onSaved: {})
        }
        .navigationDestination(item: $selectedReceipt) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .fill(product.category.tint.opacity(0.15))
                    Image(systemName: product.category.symbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(product.category.tint)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    if let brand = product.brand, !brand.isEmpty {
                        Text(brand)
                            .font(RBFont.caption)
                            .foregroundStyle(Color.rbTextSecondary)
                    }
                    Text(product.barcode)
                        .font(RBFont.caption.monospaced())
                        .foregroundStyle(Color.rbTextTertiary)
                }

                Spacer()
            }

            Button {
                isShowingPurchaseEntry = true
            } label: {
                Label("구매 기록", systemImage: "plus.circle.fill")
                    .font(RBFont.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Spacing.l)
    }

    private var factsRow: some View {
        HStack(spacing: Spacing.s) {
            fact(title: "최근 가격", value: summary.recentPrice.map { $0.formatted(as: .krw) } ?? "—")
            fact(title: "구매 횟수", value: "\(summary.purchaseCount)회")
            fact(title: "최근 구매처", value: summary.recentStoreName ?? "—")
            fact(title: "최근 구매일", value: recentPurchaseDateText)
        }
    }

    private var recentPurchaseDateText: String {
        guard let date = summary.recentPurchaseDate else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func fact(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(RBFont.caption)
                .foregroundStyle(Color.rbTextSecondary)
            Text(value)
                .font(RBFont.headline)
                .foregroundStyle(Color.rbTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var priceChart: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "가격 추이")

            Chart(summary.sortedPurchases.reversed()) { purchase in
                LineMark(
                    x: .value("Date", purchase.purchasedAt),
                    y: .value("Price", NSDecimalNumber(decimal: purchase.price).doubleValue)
                )
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Date", purchase.purchasedAt),
                    y: .value("Price", NSDecimalNumber(decimal: purchase.price).doubleValue)
                )
            }
            .foregroundStyle(Color.accentColor)
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .accessibilityLabel("가격 추이 차트")
            .accessibilityValue(priceChartAccessibilitySummary)
        }
        .cardStyle()
    }

    private var priceChartAccessibilitySummary: String {
        summary.sortedPurchases
            .map { "\($0.purchasedAt.formatted(.dateTime.month(.abbreviated).day())) \($0.price.formatted(as: .krw))" }
            .joined(separator: ", ")
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "가격 이력")

            VStack(spacing: 0) {
                ForEach(Array(summary.sortedPurchases.enumerated()), id: \.element.id) { index, purchase in
                    historyRow(purchase)
                    if index < summary.sortedPurchases.count - 1 {
                        Divider().padding(.leading, Spacing.m)
                    }
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private var relatedReceiptsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "관련 영수증")

            VStack(spacing: Spacing.s) {
                ForEach(relatedReceipts) { receipt in
                    ReceiptCard(receipt: receipt, showsItemCount: true) {
                        selectedReceipt = receipt
                    }
                }
            }
        }
    }

    private func historyRow(_ purchase: Purchase) -> some View {
        HStack {
            Text(purchase.purchasedAt.formatted(date: .abbreviated, time: .omitted))
                .font(RBFont.subheadline)
                .foregroundStyle(Color.rbTextSecondary)
                .frame(width: 90, alignment: .leading)

            Text(purchase.price.formatted(as: .krw))
                .font(RBFont.subheadline.weight(.semibold))
                .foregroundStyle(Color.rbTextPrimary)

            Spacer()

            if let store = purchase.storeName {
                Text(store)
                    .font(RBFont.caption)
                    .foregroundStyle(Color.rbTextTertiary)
            }
        }
        .padding(Spacing.m)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(product: SampleData.products[0])
    }
    .environment(ProductStore.preview())
    .environment(ReceiptStore.preview())
}
