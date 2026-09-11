//
//  ManualReceiptEntryView.swift
//  ReceiptBox
//
//  Native Form for recording a purchase — used three ways: a blank Manual
//  Entry form, the Receipt Detail edit screen (prefilled, updates that
//  receipt in place), and the OCR Review screen (prefilled from a scanned
//  draft, but still saved as a brand-new receipt). All three share this
//  one implementation and its validation/save logic.

import SwiftUI

struct ManualReceiptEntryView: View {
    enum Mode {
        /// A blank form; Save creates a new receipt.
        case create
        /// Prefilled from a scanned draft; Save still creates a new
        /// receipt (the draft was never persisted). Keeps the draft's
        /// confidence info so low-confidence fields can be flagged.
        case reviewDraft(ReceiptDraft)
        /// Prefilled from an existing receipt; Save updates it in place.
        case edit(Receipt)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(ReceiptStore.self) private var store
    @Environment(ProductStore.self) private var productStore

    private let mode: Mode
    /// Called right before this view dismisses itself after a successful
    /// save. Scan uses this to close the camera flow too once review is
    /// saved — Cancel never calls it, so Scan can tell the two apart.
    private let onSaved: (() -> Void)?

    @State private var merchantName: String
    @State private var date: Date
    @State private var totalAmountText: String
    @State private var category: SpendingCategory
    @State private var paymentMethod: PaymentMethod
    @State private var items: [DraftItem]

    init(onSaved: (() -> Void)? = nil) {
        self.mode = .create
        self.onSaved = onSaved
        _merchantName = State(initialValue: "")
        _date = State(initialValue: .now)
        _totalAmountText = State(initialValue: "")
        _category = State(initialValue: .other)
        _paymentMethod = State(initialValue: .card)
        _items = State(initialValue: [])
    }

    init(editingReceipt receipt: Receipt) {
        self.mode = .edit(receipt)
        self.onSaved = nil
        _merchantName = State(initialValue: receipt.merchantName)
        _date = State(initialValue: receipt.date)
        _totalAmountText = State(initialValue: Self.plainAmountString(from: receipt.totalAmount))
        _category = State(initialValue: receipt.category)
        _paymentMethod = State(initialValue: receipt.paymentMethod)
        _items = State(initialValue: receipt.items.map(DraftItem.init(item:)))
    }

    init(reviewingDraft draft: ReceiptDraft, onSaved: (() -> Void)? = nil) {
        self.mode = .reviewDraft(draft)
        self.onSaved = onSaved
        _merchantName = State(initialValue: draft.merchantName ?? "")
        _date = State(initialValue: draft.date ?? .now)
        _totalAmountText = State(initialValue: draft.total.map(Self.plainAmountString) ?? "")
        _category = State(initialValue: draft.category ?? .other)
        _paymentMethod = State(initialValue: draft.paymentMethod ?? .card)
        _items = State(initialValue: draft.items.map(DraftItem.init(item:)))
    }

    private struct DraftItem: Identifiable {
        let id = UUID()
        var name = ""
        var quantity = "1"
        var price = ""

        nonisolated init() {}

        nonisolated init(item: ReceiptItem) {
            name = item.name
            quantity = String(item.quantity)
            price = ManualReceiptEntryView.plainAmountString(from: item.unitPrice)
        }
    }

    private var navigationTitleText: String {
        switch mode {
        case .create: String(localized: "직접 입력")
        case .reviewDraft: String(localized: "영수증 확인")
        case .edit: String(localized: "영수증 수정")
        }
    }

    private var saveButtonTitle: String {
        switch mode {
        case .create, .edit: String(localized: "저장")
        case .reviewDraft: String(localized: "영수증 저장")
        }
    }

    private var parsedTotal: Decimal? {
        ReceiptDraftParser.parseAmount(totalAmountText)
    }

    private var isValid: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (parsedTotal ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if case .reviewDraft(let draft) = mode {
                    reviewNotice(for: draft)
                }

                Section("가맹점") {
                    TextField("예: 스타벅스", text: $merchantName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("manualEntry.merchantField")
                }

                Section("상세 정보") {
                    DatePicker("날짜", selection: $date, displayedComponents: [.date])

                    HStack {
                        Text("합계")
                        Spacer()
                        TextField("0", text: $totalAmountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("manualEntry.totalField")
                    }

                    Picker("카테고리", selection: $category) {
                        ForEach(SpendingCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }

                    Picker("결제 수단", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Label(method.displayName, systemImage: method.symbolName)
                                .tag(method)
                        }
                    }
                }

                Section("상품") {
                    ForEach($items) { $item in
                        itemRow($item)
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }

                    Button {
                        items.append(DraftItem())
                    } label: {
                        Label("상품 추가", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .accessibilityIdentifier("manualEntry.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                        .accessibilityIdentifier("manualEntry.saveButton")
                }
            }
        }
    }

    private func reviewNotice(for draft: ReceiptDraft) -> some View {
        Section {
            Label {
                Text(reviewNoticeText(for: draft))
            } icon: {
                Image(systemName: draft.lowConfidenceFields.isEmpty ? "checkmark.circle.fill" : "text.viewfinder")
                    .foregroundStyle(draft.lowConfidenceFields.isEmpty ? Color.rbPositive : Color.accentColor)
            }
            .font(RBFont.subheadline)
        }
    }

    private func reviewNoticeText(for draft: ReceiptDraft) -> String {
        if draft.lowConfidenceFields.isEmpty {
            return String(localized: "잘 인식됐어요 — 아래 내용을 확인하고 저장해주세요.")
        }
        let fieldNames = draft.lowConfidenceFields
            .sorted { String(describing: $0) < String(describing: $1) }
            .map { field -> String in
                switch field {
                case .merchant: String(localized: "가맹점")
                case .date: String(localized: "날짜")
                case .total: String(localized: "합계")
                }
            }
        let joined = fieldNames.joined(separator: ", ")
        let suffix = String(localized: "항목을 정확히 인식하지 못했어요 — 아래에서 확인해주세요.")
        return "\(joined) \(suffix)"
    }

    private func itemRow(_ item: Binding<DraftItem>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("상품명", text: item.name)

            HStack(spacing: Spacing.s) {
                HStack(spacing: 4) {
                    Text("수량")
                    TextField("1", text: item.quantity)
                        .keyboardType(.numberPad)
                        .frame(width: 40)
                }
                Divider().frame(height: 14)
                HStack(spacing: 4) {
                    Text("가격")
                    TextField("0", text: item.price)
                        .keyboardType(.numberPad)
                }
            }
            .font(RBFont.caption)
            .foregroundStyle(Color.rbTextSecondary)
        }
    }

    private func save() {
        guard let total = parsedTotal else { return }

        let receiptItems: [ReceiptItem] = items.compactMap { draft in
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            return ReceiptItem(
                name: trimmedName,
                quantity: ReceiptDraftParser.parseQuantity(draft.quantity),
                unitPrice: ReceiptDraftParser.parseAmount(draft.price) ?? 0
            )
        }

        let trimmedMerchant = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .edit(let existing):
            let updated = Receipt(
                id: existing.id,
                merchantName: trimmedMerchant,
                date: date,
                totalAmount: total,
                currency: existing.currency,
                category: category,
                paymentMethod: paymentMethod,
                items: receiptItems,
                createdAt: existing.createdAt,
                updatedAt: .now
            )
            let linked = ReceiptProductLinker.linkedReceipt(updated, existingProducts: productStore.products)
            store.update(linked)
            productStore.syncPurchases(for: linked)
        case .create, .reviewDraft:
            let receipt = Receipt(
                merchantName: trimmedMerchant,
                date: date,
                totalAmount: total,
                category: category,
                paymentMethod: paymentMethod,
                items: receiptItems
            )
            let linked = ReceiptProductLinker.linkedReceipt(receipt, existingProducts: productStore.products)
            store.add(linked)
            productStore.syncPurchases(for: linked)
        }

        onSaved?()

        dismiss()
    }

    nonisolated private static func plainAmountString(from decimal: Decimal) -> String {
        NSDecimalNumber(decimal: decimal).stringValue
    }
}

#Preview("Add") {
    ManualReceiptEntryView()
        .environment(ReceiptStore.preview())
        .environment(ProductStore.preview())
}

#Preview("Edit") {
    ManualReceiptEntryView(editingReceipt: SampleData.receipts[0])
        .environment(ReceiptStore.preview())
        .environment(ProductStore.preview())
}

#Preview("Review Draft") {
    ManualReceiptEntryView(reviewingDraft: ReceiptDraft(
        merchantName: "Starbucks",
        date: .now,
        total: 5500,
        items: [ReceiptItem(name: "아메리카노", unitPrice: 5500)],
        paymentMethod: .card,
        category: .cafe,
        lowConfidenceFields: [.date]
    ))
    .environment(ReceiptStore.preview())
    .environment(ProductStore.preview())
}
