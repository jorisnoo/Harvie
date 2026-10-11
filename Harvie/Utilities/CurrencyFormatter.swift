//
//  CurrencyFormatter.swift
//  Harvie
//

import Foundation

struct CurrencyFormatter {
    private static var currencyFormatters: [String: NumberFormatter] = [:]
    private static let decimalFormatter = fixedFormatter()

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

    static func rounded(_ amount: Decimal, currency: String) -> Decimal {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, formatter.maximumFractionDigits, .plain)
        return result
    }

    static func formatDecimal(_ amount: Decimal, groupingSeparator: String = "'") -> String {
        if groupingSeparator == "'" {
            return decimalFormatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        }

        let f = fixedFormatter(groupingSeparator: groupingSeparator)
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    /// A formatter for fixed-format numbers (invoice templates, the QR slip), unlike
    /// `format`, which follows the user's locale for on-screen display: always ASCII
    /// digits and "." as decimal separator, and halves round away from zero like `rounded`.
    nonisolated static func fixedFormatter(
        minimumFractionDigits: Int = 2,
        maximumFractionDigits: Int = 2,
        groupingSeparator: String = "'"
    ) -> NumberFormatter {
        let f = NumberFormatter()
        // Set the locale first: assigning it resets the separators.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.roundingMode = .halfUp
        f.minimumFractionDigits = minimumFractionDigits
        f.maximumFractionDigits = maximumFractionDigits
        f.decimalSeparator = "."
        f.usesGroupingSeparator = !groupingSeparator.isEmpty
        f.groupingSeparator = groupingSeparator
        f.groupingSize = 3
        return f
    }
}
