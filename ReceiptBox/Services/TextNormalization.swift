//
//  TextNormalization.swift
//  ReceiptBox
//
//  A single, conservative normalization shared by ProductMatcher (item name
//  -> Product) and StoreAnalytics (merchant name grouping): trim, case-fold,
//  collapse internal whitespace. Deliberately does not do anything fuzzier
//  (no punctuation stripping, no substring/edit-distance matching) — the
//  callers both rely on this being exact-after-normalization so two
//  genuinely different names never collide.
//

import Foundation

nonisolated enum TextNormalization {
    static func normalizedForMatching(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
