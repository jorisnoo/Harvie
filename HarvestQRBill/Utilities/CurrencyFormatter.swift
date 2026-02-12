//
//  CurrencyFormatter.swift
//  HarvestQRBill
//

import Foundation

struct CurrencyFormatter {
    private static var currencyFormatters: [String: NumberFormatter] = [:]
    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = "."
        f.groupingSeparator = " "
        return f
    }()

    static func format(_ amount: Decimal, currency: String) -> String {
        let formatter = currencyFormatters[currency] ?? {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = currency
            currencyFormatters[currency] = f
            return f
        }()
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static func formatDecimal(_ amount: Decimal, groupingSeparator: String = " ") -> String {
        if groupingSeparator == " " {
            return decimalFormatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        }

        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = "."
        f.groupingSeparator = groupingSeparator
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
