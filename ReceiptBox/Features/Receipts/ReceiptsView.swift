//
//  ReceiptsView.swift
//  ReceiptBox
//
//  The full purchase history, reached from Home's "See All". Pushed onto
//  Home's own NavigationPath rather than owning a stack of its own, so
//  tapping a receipt here reuses Home's existing
//  `.navigationDestination(for: Receipt.self)` registration.

import SwiftUI

struct ReceiptsView: View {
    @Environment(ReceiptStore.self) private var store
    @Environment(ProductStore.self) private var productStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var path: NavigationPath

    @State private var searchText = ""
    @State private var pendingDeleteReceipt: Receipt?

    private var filteredReceipts: [Receipt] {
        ReceiptSearch.filter(store.receipts, query: searchText)
    }

    private var matchedProducts: [Product] {
        ProductSearch.filter(productStore.products, query: searchText)
    }

    private var groups: [ReceiptGroup] {
        ReceiptGrouping.byMonth(filteredReceipts)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasAnyResults: Bool {
        !filteredReceipts.isEmpty || !matchedProducts.isEmpty
    }

    var body: some View {
        content
            .background(Color.rbBackground)
            .navigationTitle("영수증")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "영수증, 상점 또는 상품 검색")
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: store.receipts)
            .confirmationDialog(
                "영수증을 삭제할까요?",
                isPresented: Binding(
                    get: { pendingDeleteReceipt != nil },
                    set: { isPresented in if !isPresented { pendingDeleteReceipt = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let receipt = pendingDeleteReceipt {
                        store.delete(receipt)
                    }
                    pendingDeleteReceipt = nil
                }
                Button("취소", role: .cancel) {
                    pendingDeleteReceipt = nil
                }
            } message: {
                if let receipt = pendingDeleteReceipt {
                    Text(deleteConfirmationMessage(for: receipt))
                }
            }
    }

    private func deleteConfirmationMessage(for receipt: Receipt) -> String {
        let undoNotice = String(localized: "삭제한 영수증은 다시 복구할 수 없어요.")
        return "\(receipt.merchantName) · \(receipt.formattedTotal). \(undoNotice)"
    }

    @ViewBuilder
    private var content: some View {
        if store.receipts.isEmpty {
            EmptyStateView(
                systemImage: "tray",
                title: "아직 영수증이 없어요",
                message: "영수증을 스캔하거나 추가하고 지출 관리를 시작해보세요."
            )
            .padding(.top, Spacing.xl)
        } else if !hasAnyResults {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "검색 결과가 없어요",
                message: noMatchesMessage
            )
            .padding(.top, Spacing.xl)
        } else {
            list
        }
    }

    private var noMatchesMessage: String {
        let suffix = String(localized: "에 대한 결과를 찾지 못했어요.")
        return "\u{201C}\(searchText)\u{201D}\(suffix)"
    }

    private var list: some View {
        List {
            if isSearching, !matchedProducts.isEmpty {
                Section {
                    ForEach(matchedProducts) { product in
                        productRow(product)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.m, bottom: Spacing.xs, trailing: Spacing.m))
                    }
                } header: {
                    Text("관련 상품")
                        .font(RBFont.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rbTextSecondary)
                        .textCase(nil)
                }
            }

            ForEach(groups) { group in
                Section {
                    ForEach(group.receipts) { receipt in
                        ReceiptCard(receipt: receipt, showsItemCount: true) {
                            path.append(receipt)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.m, bottom: Spacing.xs, trailing: Spacing.m))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDeleteReceipt = receipt
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(group.title)
                        .font(RBFont.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rbTextSecondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func productRow(_ product: Product) -> some View {
        Button {
            path.append(product)
        } label: {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .fill(product.category.tint.opacity(0.15))
                    Image(systemName: product.category.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(product.category.tint)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(RBFont.headline)
                        .foregroundStyle(Color.rbTextPrimary)
                        .lineLimit(1)
                    Text(product.brand ?? product.barcode)
                        .font(RBFont.caption)
                        .foregroundStyle(Color.rbTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.s)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.rbTextTertiary)
            }
        }
        .buttonStyle(PressableStyle())
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.name), \(product.brand ?? "")")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    NavigationStack {
        ReceiptsView(path: .constant(NavigationPath()))
    }
    .environment(ReceiptStore.preview())
    .environment(ProductStore.preview())
}
