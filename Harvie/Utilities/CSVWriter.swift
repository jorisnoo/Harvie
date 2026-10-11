//
//  CSVWriter.swift
//  Harvie
//

import Foundation

/// Flattens an array of JSON objects (as produced by `JSONSerialization`)
/// into RFC 4180-compliant CSV. Nested objects and arrays are JSON-encoded
/// into a single cell so no information is lost. Text that a spreadsheet would
/// evaluate as a formula is prefixed with `'` so it opens as plain text.
enum CSVWriter {

    /// Produces CSV bytes for the given rows. Column order: `id` first (if
    /// present), then remaining keys alphabetically, with `created_at` and
    /// `updated_at` pushed to the end.
    nonisolated static func makeCSV(rows: [[String: Any]]) -> Data {
        let columns = columnOrder(for: rows)

        var output = ""
        output.append(columns.map { escape(neutralizingFormula($0)) }.joined(separator: ","))
        output.append("\r\n")

        for row in rows {
            let line = columns.map { column -> String in
                escape(stringify(row[column]))
            }.joined(separator: ",")
            output.append(line)
            output.append("\r\n")
        }

        return Data(output.utf8)
    }

    nonisolated private static func columnOrder(for rows: [[String: Any]]) -> [String] {
        var keys = Set<String>()
        for row in rows {
            keys.formUnion(row.keys)
        }

        let pinnedFirst = ["id"]
        let pinnedLast = ["created_at", "updated_at"]

        let middle = keys
            .subtracting(pinnedFirst)
            .subtracting(pinnedLast)
            .sorted()

        return pinnedFirst.filter { keys.contains($0) }
            + middle
            + pinnedLast.filter { keys.contains($0) }
    }

    nonisolated private static func stringify(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }

        switch value {
        case let s as String:
            return neutralizingFormula(s)
        case let n as NSNumber:
            // `as? Bool` would also match NSNumbers holding exactly 0 or 1 (SE-0170
            // bridging), so distinguish real JSON booleans by their CF type instead.
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return n.boolValue ? "true" : "false"
            }
            return n.stringValue
        case is [Any], is [String: Any]:
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return ""
        default:
            return String(describing: value)
        }
    }

    /// Guards against CSV injection: spreadsheets treat text starting with these
    /// characters as a formula. Numbers arrive as `NSNumber`, so negative values
    /// never reach this and stay numeric.
    nonisolated private static func neutralizingFormula(_ text: String) -> String {
        guard let first = text.unicodeScalars.first else { return text }
        switch first {
        case "=", "+", "-", "@", "\t", "\r":
            return "'" + text
        default:
            return text
        }
    }

    nonisolated private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
