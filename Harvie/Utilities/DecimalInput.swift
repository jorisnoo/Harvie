import Foundation

/// Parses a complete number using the separators displayed by the user's locale.
struct DecimalInput {
    static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        let decimal = formatter.decimalSeparator ?? "."
        let grouping = formatter.groupingSeparator ?? ","
        let separator = NSRegularExpression.escapedPattern(for: grouping)
        let decimalPattern = NSRegularExpression.escapedPattern(for: decimal)
        let groupSize = max(1, formatter.groupingSize)
        let secondarySize = formatter.secondaryGroupingSize > 0 ? formatter.secondaryGroupingSize : groupSize
        let integer = "(?:[0-9]+|[0-9]{1,\(secondarySize)}(?:\(separator)[0-9]{\(secondarySize)})*\(separator)[0-9]{\(groupSize)})"
        let pattern = "\\A[+-]?(?:\(integer)(?:\(decimalPattern)[0-9]+)?|\(decimalPattern)[0-9]+)\\z"
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["'", "’"].contains(grouping) {
            trimmed = trimmed.replacingOccurrences(of: "’", with: grouping).replacingOccurrences(of: "'", with: grouping)
        }
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let normalized = trimmed.replacingOccurrences(of: grouping, with: "")
            .replacingOccurrences(of: decimal, with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else { return nil }
        return value
    }
}
