//
//  PurchaseEntryView.swift
//  ReceiptBox
//
//  Records one purchase of a Product: price, quantity, store, date. Reuses
//  ReceiptDraftParser for the same tolerant amount/quantity text parsing
//  ManualReceiptEntryView already relies on, rather than re-implementing it.

import SwiftUI

struct PurchaseEntryView: View {
    let product: Product
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ProductStore.self) private var productStore

    @State private var priceText: String
    @State private var quantityText = "1"
    @State private var storeName: String
    @State private var purchasedAt = Date.now

    init(product: Product, defaultStoreName: String? = nil, onSaved: @escaping () -> Void) {
        self.product = product
        self.onSaved = onSaved
        _priceText = State(initialValue: "")
        _storeName = State(initialValue: defaultStoreName ?? "")
    }

    private var parsedPrice: Decimal? {
        ReceiptDraftParser.parseAmount(priceText)
    }

    private var isValid: Bool {
        (parsedPrice ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(product.name) {
                    HStack {
                        Text("가격")
                        Spacer()
                        TextField("0", text: $priceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("수량")
                        Spacer()
                        TextField("1", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    TextField("구매처", text: $storeName)
                        .textInputAutocapitalization(.words)
                    DatePicker("구매일", selection: $purchasedAt, displayedComponents: [.date])
                }
            }
            .navigationTitle("구매 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let price = parsedPrice else { return }
        let trimmedStore = storeName.trimmingCharacters(in: .whitespacesAndNewlines)

        let purchase = Purchase(
            productID: product.id,
            price: price,
            quantity: ReceiptDraftParser.parseQuantity(quantityText),
            storeName: trimmedStore.isEmpty ? nil : trimmedStore,
            purchasedAt: purchasedAt
        )
        productStore.addPurchase(purchase)
        onSaved()
        dismiss()
    }
}

#Preview {
    PurchaseEntryView(product: SampleData.products[0], onSaved: {})
        .environment(ProductStore.preview())
}
