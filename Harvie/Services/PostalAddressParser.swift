//
//  PostalAddressParser.swift
//  Harvie
//

import Foundation

/// Turns a free-form Harvest client address into a structured QR-bill debtor address.
///
/// Harvest stores addresses as multi-line text, typically
///
///     [c/o, department or PO box lines]
///     Street 12
///     8000 Zürich
///     [Country]
///
/// Parsing is deliberately conservative: when the town line or the country can't be
/// determined with confidence it returns nil, and the QR bill leaves the debtor field
/// blank to be filled in by hand rather than encoding a wrong address.
enum PostalAddressParser {
    nonisolated static func parse(_ address: String, name: String) -> StructuredAddress? {
        var lines = address.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var country: String?
        if let last = lines.last, let code = countryCode(from: last) {
            country = code
            lines.removeLast()
        }

        // The town line is the last remaining line ("London" / "NW1 6XE" in UK addresses
        // may be split over two lines).
        guard var placeLine = lines.popLast() else { return nil }
        if country == "GB", isUKPostcode(placeLine), let town = lines.popLast() {
            placeLine = "\(town) \(placeLine)"
        }
        guard let parsed = place(from: placeLine, country: country),
              let resolvedCountry = country ?? parsed.countryHint else { return nil }

        var streetName: String?
        var buildingNumber: String?
        if let street = lines.popLast() {
            let split = splitBuildingNumber(street)
            buildingNumber = split.number
            // Lines above the street (c/o, department, PO box) are kept as-is.
            streetName = (lines + [split.street]).joined(separator: "\n")
        }

        return StructuredAddress(
            name: name,
            streetName: streetName,
            buildingNumber: buildingNumber,
            postalCode: parsed.postalCode,
            town: parsed.town,
            country: resolvedCountry
        )
    }

    /// Resolves a country line given as an ISO code or as a country name in English,
    /// German, French or Italian (plus a few common variants).
    nonisolated static func countryCode(from line: String) -> String? {
        let key = normalized(line)
        if key.count == 2, Locale.isoRegionCodes.contains(key.uppercased()) {
            return key.uppercased()
        }
        return countryNames[key]
    }

    // MARK: - Private

    /// `countryHint` is the country implied by the line itself, used when the address names none.
    private typealias Place = (postalCode: String, town: String, countryHint: String?)

    nonisolated private static func place(from line: String, country: String?) -> Place? {
        switch country {
        case "GB":
            // "London NW1 6XE"
            guard let match = line.wholeMatch(of: #/(.+?),?\s+([A-Za-z]{1,2}\d[A-Za-z\d]?\s*\d[A-Za-z]{2})/#) else {
                return nil
            }
            return (match.2.uppercased(), String(match.1), nil)
        case "US":
            // "Mountain View, CA 94043"
            guard let match = line.wholeMatch(of: #/(.+?),?\s+(?:([A-Z]{2})\s+)?(\d{5}(?:-\d{4})?)/#) else {
                return nil
            }
            let town = [match.1, match.2].compactMap { $0 }.joined(separator: " ")
            return (String(match.3), town, nil)
        default:
            // "8000 Zürich", optionally with a country prefix: "CH-8000 Zürich", "FL-9490 Vaduz"
            guard let match = line.wholeMatch(of: #/(?:([A-Za-z]{1,3})-)?(\d{4,5})\s+(.+)/#) else {
                return nil
            }
            let postalCode = String(match.2)
            // Without a country line, only a Swiss-looking (4-digit) postcode is trusted.
            let hint = match.1.flatMap { prefixCountry(String($0)) } ?? (postalCode.count == 4 ? "CH" : nil)
            return (postalCode, String(match.3), hint)
        }
    }

    /// Splits "Bahnhofstrasse 42" or "221B Baker Street" into street and building number.
    nonisolated private static func splitBuildingNumber(_ line: String) -> (street: String, number: String?) {
        let words = line.split(separator: " ")
        guard words.count > 1, let first = words.first, let last = words.last else { return (line, nil) }
        if last.contains(where: \.isNumber) {
            return (words.dropLast().joined(separator: " "), String(last))
        }
        if first.contains(where: \.isNumber) {
            return (words.dropFirst().joined(separator: " "), first.trimmingCharacters(in: CharacterSet(charactersIn: ",")))
        }
        return (line, nil)
    }

    nonisolated private static func isUKPostcode(_ line: String) -> Bool {
        line.wholeMatch(of: #/[A-Za-z]{1,2}\d[A-Za-z\d]?\s*\d[A-Za-z]{2}/#) != nil
    }

    /// Country prefixes in front of postcodes: ISO codes or the old vehicle codes.
    nonisolated private static func prefixCountry(_ prefix: String) -> String? {
        let code = prefix.uppercased()
        let vehicleCodes = ["FL": "LI", "D": "DE", "A": "AT", "F": "FR", "I": "IT", "L": "LU"]
        if let country = vehicleCodes[code] { return country }
        return Locale.isoRegionCodes.contains(code) ? code : nil
    }

    nonisolated private static func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
    }

    nonisolated private static let countryNames: [String: String] = {
        var names = [
            "uk": "GB", "great britain": "GB", "grossbritannien": "GB", "england": "GB",
            "scotland": "GB", "wales": "GB", "northern ireland": "GB",
            "usa": "US", "united states of america": "US",
            "holland": "NL", "the netherlands": "NL",
            "furstentum liechtenstein": "LI"
        ]
        for language in ["en", "de", "fr", "it"] {
            let locale = Locale(identifier: language)
            for code in Locale.isoRegionCodes {
                guard let name = locale.localizedString(forRegionCode: code) else { continue }
                let key = normalized(name)
                if names[key] == nil { names[key] = code }
            }
        }
        return names
    }()
}
