//
//  ReceiptEntity+Mapping.swift
//  ReceiptBox
//
//  Conversion between the SwiftData persistence entities and the plain
//  Receipt/ReceiptItem domain structs the rest of the app already uses.
//  This is the one place the two representations are allowed to touch.

import Foundation

extension ReceiptEntity {
    convenience init(receipt: Receipt) {
        self.init(
            id: receipt.id,
            merchantName: receipt.merchantName,
            date: receipt.date,
            totalAmount: receipt.totalAmount,
            currencyRaw: receipt.currency.rawValue,
            categoryRaw: receipt.category.rawValue,
            paymentMethodRaw: receipt.paymentMethod.rawValue,
            createdAt: receipt.createdAt,
            updatedAt: receipt.updatedAt
        )
        items = receipt.items.enumerated().map { index, item in
            ReceiptItemEntity(item: item, sortIndex: index)
        }
    }

    /// Updates the scalar fields to match `receipt`. Callers are
    /// responsible for reconciling `items` themselves, since that requires
    /// a `ModelContext` to delete orphaned item entities.
    func updateScalarFields(from receipt: Receipt) {
        merchantName = receipt.merchantName
        date = receipt.date
        totalAmount = receipt.totalAmount
        currencyRaw = receipt.currency.rawValue
        categoryRaw = receipt.category.rawValue
        paymentMethodRaw = receipt.paymentMethod.rawValue
        updatedAt = .now
    }

    var asDomain: Receipt {
        Receipt(
            id: id,
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            currency: Currency(rawValue: currencyRaw) ?? .krw,
            category: SpendingCategory(rawValue: categoryRaw) ?? .other,
            paymentMethod: PaymentMethod(rawValue: paymentMethodRaw) ?? .other,
            items: items.sorted { $0.sortIndex < $1.sortIndex }.map(\.asDomain),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension ReceiptItemEntity {
    convenience init(item: ReceiptItem, sortIndex: Int) {
        self.init(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            categoryRaw: item.category?.rawValue,
            sortIndex: sortIndex,
            productID: item.productID
        )
    }

    var asDomain: ReceiptItem {
        ReceiptItem(
            id: id,
            name: name,
            quantity: quantity,
            unitPrice: unitPrice,
            category: categoryRaw.flatMap(SpendingCategory.init(rawValue:)),
            productID: productID
        )
    }
}
