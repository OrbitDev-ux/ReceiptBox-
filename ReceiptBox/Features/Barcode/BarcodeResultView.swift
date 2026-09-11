//
//  BarcodeResultView.swift
//  ReceiptBox
//
//  Presented as a sheet once BarcodeScannerView gets a result. Two modes,
//  two different terminal points, both ending by calling `onFinished`:
//
//  Found      → recent price/store summary → "구매 기록" → PurchaseEntryView
//               → save → done.
//  Not found  → barcode + "상품 직접 등록" → ProductEntryView → save →
//               pushes to ProductDetailView (where "구매 기록" is also
//               available) → person taps Done when they're finished.
//
//  Swiping the sheet away without saving anything calls neither — the
//  caller's onChange(of: sheetRoute) resets the scanner instead of
//  finishing, matching ScanView's own dismiss-without-saving behavior.

import SwiftUI

struct BarcodeResultView: View {
    enum Mode {
        case found(Product)
        case notFound(barcode: String)
    }

    let mode: Mode
    /// Called once the flow has produced a saved Purchase (found path) or a
    /// registered Product the person is done with (not-found path) — the
    /// signal for the presenter to dismiss the whole barcode scanner.
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ProductStore.self) private var productStore

    @State private var isShowingPurchaseEntry = false
    @State private var registrationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $registrationPath) {
            Group {
                switch mode {
                case .found(let product):
                    foundContent(product)
                case .notFound(let barcode):
                    ProductEntryView(prefilledBarcode: barcode) { newProduct in
                        registrationPath.append(newProduct)
                    }
                }
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product, isPresentedModally: true, onDone: onFinished)
            }
            .toolbar {
                if case .found = mode {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Found

    private func foundContent(_ product: Product) -> some View {
        let summary = PriceHistorySummary.make(from: productStore.purchases(forProduct: product.id))

        return ScrollView {
            VStack(spacing: Spacing.l) {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: product.category.symbolName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(product.category.tint)
                        .frame(width: 72, height: 72)
                        .background(product.category.tint.opacity(0.15), in: Circle())
                        .padding(.bottom, Spacing.xs)

                    Text(product.name)
                        .font(RBFont.screenTitle)
                        .foregroundStyle(Color.rbTextPrimary)
                        .multilineTextAlignment(.center)

                    if let brand = product.brand, !brand.isEmpty {
                        Text(brand)
                            .font(RBFont.subheadline)
                            .foregroundStyle(Color.rbTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.l)

                if summary.purchaseCount > 0 {
                    VStack(spacing: Spacing.m) {
                        HStack {
                            recentFact(title: "최근 가격", value: summary.recentPrice.map { $0.formatted(as: .krw) } ?? "—")
                            Divider().frame(height: 32)
                            recentFact(title: "최근 구매처", value: summary.recentStoreName ?? "—")
                        }
                    }
                    .cardStyle(padding: Spacing.l)
                    .padding(.horizontal, Spacing.m)
                } else {
                    Text("처음 구매하는 상품이에요")
                        .font(RBFont.subheadline)
                        .foregroundStyle(Color.rbTextSecondary)
                }

                Spacer(minLength: Spacing.xl)

                Button {
                    isShowingPurchaseEntry = true
                } label: {
                    Text("구매 기록")
                        .font(RBFont.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clipShape(Capsule())
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.l)
            }
        }
        .background(Color.rbBackground)
        .navigationTitle("상품 인식")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingPurchaseEntry) {
            PurchaseEntryView(product: product, defaultStoreName: summary.recentStoreName) {
                onFinished()
            }
        }
    }

    private func recentFact(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(RBFont.caption)
                .foregroundStyle(Color.rbTextSecondary)
            Text(value)
                .font(RBFont.headline)
                .foregroundStyle(Color.rbTextPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Found") {
    BarcodeResultView(mode: .found(SampleData.products[0]), onFinished: {})
        .environment(ProductStore.preview())
}

#Preview("Not Found") {
    BarcodeResultView(mode: .notFound(barcode: "8801234567890"), onFinished: {})
        .environment(ProductStore.preview())
}
