//
//  CurrencyFormatter.swift
//  Harvester
//

import Foundation

struct CurrencyFormatter {
    static func format(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static func formatDecimal(_ amount: Decimal, groupingSeparator: String = " ") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = groupingSeparator
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
