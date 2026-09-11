//
//  ReceiptDraftParser.swift
//  ReceiptBox
//
//  Pure parsing helpers for the manual-entry form's free-text number
//  fields, pulled out of the view so the parsing rules are testable on
//  their own.

import Foundation

enum ReceiptDraftParser {
    static func parseAmount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }

    /// Quantities default to (and never fall below) 1 — an empty or
    /// non-numeric field shouldn't zero out an otherwise valid item.
    static func parseQuantity(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Int(trimmed) ?? 1
        return max(value, 1)
    }
}
