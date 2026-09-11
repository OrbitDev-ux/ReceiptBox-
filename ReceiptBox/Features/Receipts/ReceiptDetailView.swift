//
//  ReceiptDetailView.swift
//  ReceiptBox
//

import SwiftUI

struct ReceiptDetailView: View {
    private let initialReceipt: Receipt

    @Environment(ReceiptStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingEditSheet = false
    @State private var isShowingDeleteConfirmation = false

    init(receipt: Receipt) {
        self.initialReceipt = receipt
    }

    /// Re-resolved from the store on every access so edits (and deletions
    /// elsewhere, e.g. a swipe in Receipts) are reflected immediately
    /// instead of this screen showing a frozen navigation-time snapshot.
    private var receipt: Receipt {
        store.receipts.first { $0.id == initialReceipt.id } ?? initialReceipt
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header
                badgesRow

                if !receipt.items.isEmpty {
                    itemsSection
                }
            }
            .padding(Spacing.m)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.rbBackground)
        .navigationTitle(receipt.merchantName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("영수증 공유")
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        isShowingEditSheet = true
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("receiptDetail.editMenuItem")
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .accessibilityIdentifier("receiptDetail.deleteMenuItem")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("더 보기")
                .accessibilityIdentifier("receiptDetail.moreButton")
            }
        }
        .onChange(of: store.receipts) { _, receipts in
            if !receipts.contains(where: { $0.id == initialReceipt.id }) {
                dismiss()
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            ManualReceiptEntryView(editingReceipt: receipt)
        }
        .confirmationDialog(
            "영수증을 삭제할까요?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                store.delete(receipt)
            }
            .accessibilityIdentifier("receiptDetail.confirmDeleteButton")
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제한 영수증은 다시 복구할 수 없어요.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName)
                    .font(RBFont.screenTitle)
                    .foregroundStyle(Color.rbTextPrimary)
                Text(receipt.date.formatted(date: .long, time: .shortened))
                    .font(RBFont.subheadline)
                    .foregroundStyle(Color.rbTextSecondary)
            }

            AmountText(amount: receipt.totalAmount, currency: receipt.currency, style: .large)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Spacing.l)
    }

    private var badgesRow: some View {
        HStack(spacing: Spacing.s) {
            Badge(category: receipt.category)
            Badge(paymentMethod: receipt.paymentMethod)
            Spacer()
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "상품")

            VStack(spacing: 0) {
                ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
                    itemRow(item)
                    if index < receipt.items.count - 1 {
                        Divider().padding(.leading, Spacing.m)
                    }
                }
            }
            .cardStyle(padding: 0)
        }
    }

    private func itemRow(_ item: ReceiptItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(RBFont.body)
                    .foregroundStyle(Color.rbTextPrimary)
                Text(quantityLine(for: item))
                    .font(RBFont.caption)
                    .foregroundStyle(Color.rbTextSecondary)
            }
            Spacer()
            Text(item.totalPrice.formatted(as: receipt.currency))
                .font(RBFont.subheadline.weight(.medium))
                .foregroundStyle(Color.rbTextPrimary)
        }
        .padding(Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private func quantityLine(for item: ReceiptItem) -> String {
        let qtyLabel = String(localized: "수량")
        return "\(qtyLabel) \(item.quantity) \u{00D7} \(item.unitPrice.formatted(as: receipt.currency))"
    }

    private var shareText: String {
        let totalLabel = String(localized: "합계")
        var lines = [
            receipt.merchantName,
            receipt.date.formatted(date: .long, time: .omitted),
            "\(totalLabel): \(receipt.formattedTotal)"
        ]
        if !receipt.items.isEmpty {
            lines.append("")
            lines.append(contentsOf: receipt.items.map {
                "\($0.name) x\($0.quantity) - \($0.totalPrice.formatted(as: receipt.currency))"
            })
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        ReceiptDetailView(receipt: SampleData.receipts[0])
    }
    .environment(ReceiptStore.preview())
    .environment(ProductStore.preview())
}
