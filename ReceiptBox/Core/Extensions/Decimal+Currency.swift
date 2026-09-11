//
//  Decimal+Currency.swift
//  ReceiptBox
//

import Foundation

extension Decimal {
    /// Formats the value for display, independent of the user's locale so
    /// currency presentation stays predictable (e.g. "₩12,500", "$4.20").
    nonisolated func formatted(as currency: Currency) -> String {
        switch currency {
        case .krw:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            let digits = formatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(self)"
            return "₩\(digits)"
        case .usd:
            return self.formatted(.currency(code: currency.code))
        }
    }
}
