//
//  AddReceiptOptionsView.swift
//  ReceiptBox
//
//  The entry point for recording a purchase: a compact chooser between the
//  three capture methods — all three are functional.

import SwiftUI

struct AddReceiptOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    var onSelectReceiptScan: () -> Void
    var onSelectBarcodeScan: () -> Void
    var onSelectManualEntry: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s) {
                optionRow(
                    icon: "doc.text.viewfinder",
                    tint: .blue,
                    title: "영수증 스캔",
                    subtitle: "종이 영수증을 촬영하세요",
                    action: onSelectReceiptScan
                )
                .accessibilityIdentifier("addReceipt.scanOption")
                optionRow(
                    icon: "barcode.viewfinder",
                    tint: .purple,
                    title: "바코드 스캔",
                    subtitle: "상품 바코드로 빠르게 기록하세요",
                    action: onSelectBarcodeScan
                )
                .accessibilityIdentifier("addReceipt.barcodeOption")
                optionRow(
                    icon: "square.and.pencil",
                    tint: .green,
                    title: "직접 입력",
                    subtitle: "내용을 직접 입력하세요",
                    action: onSelectManualEntry
                )
                .accessibilityIdentifier("addReceipt.manualOption")
                Spacer(minLength: 0)
            }
            .padding(Spacing.m)
            .padding(.top, Spacing.s)
            .background(Color.rbBackground)
            .navigationTitle("영수증 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func optionRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .fill(tint.opacity(0.15))
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(RBFont.headline)
                        .foregroundStyle(Color.rbTextPrimary)
                    Text(LocalizedStringKey(subtitle))
                        .font(RBFont.caption)
                        .foregroundStyle(Color.rbTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rbTextTertiary)
            }
        }
        .buttonStyle(PressableStyle())
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    AddReceiptOptionsView(onSelectReceiptScan: {}, onSelectBarcodeScan: {}, onSelectManualEntry: {})
}
