//
//  ProductEntryView.swift
//  ReceiptBox
//
//  Manual product registration, reached only from the barcode "not found"
//  flow today — the barcode arrives pre-filled but editable, in case a
//  digit was misread. Always embedded inside a parent NavigationStack
//  (BarcodeResultView's), so this doesn't own one itself.

import SwiftUI

struct ProductEntryView: View {
    let prefilledBarcode: String
    let onSaved: (Product) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ProductStore.self) private var productStore

    @State private var name = ""
    @State private var brand = ""
    @State private var barcodeText: String
    @State private var category: SpendingCategory = .grocery
    @State private var unit = ""

    init(prefilledBarcode: String, onSaved: @escaping (Product) -> Void) {
        self.prefilledBarcode = prefilledBarcode
        self.onSaved = onSaved
        _barcodeText = State(initialValue: prefilledBarcode)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !barcodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                Label {
                    Text("상품을 찾지 못했어요 — 직접 등록하면 다음부터 바로 인식돼요.")
                } icon: {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(Color.accentColor)
                }
                .font(RBFont.subheadline)
            }

            Section("상품명") {
                TextField("예: 펩시 제로", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section("상세 정보") {
                TextField("브랜드", text: $brand)
                    .textInputAutocapitalization(.words)
                TextField("바코드", text: $barcodeText)
                    .keyboardType(.numberPad)
                Picker("카테고리", selection: $category) {
                    ForEach(SpendingCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.symbolName)
                            .tag(category)
                    }
                }
                TextField("단위 (예: 500ml)", text: $unit)
            }
        }
        .navigationTitle("상품 등록")
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

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)

        let product = Product(
            barcode: barcodeText,
            name: trimmedName,
            brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
            category: category,
            unit: trimmedUnit.isEmpty ? nil : trimmedUnit,
            isUserCreated: true
        )
        let saved = productStore.createProduct(product)
        onSaved(saved)
    }
}

#Preview {
    NavigationStack {
        ProductEntryView(prefilledBarcode: "8801234567890", onSaved: { _ in })
    }
    .environment(ProductStore.preview())
}
