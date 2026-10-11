//
//  QRBillText.swift
//  Harvie
//

import Foundation

/// Restricts text to the characters the Swiss Payments Code permits in a QR bill
/// (Implementation Guidelines v2.3, Annex: Basic Latin, Latin-1 Supplement, Latin
/// Extended-A, plus Ș ș Ț ț and €). Anything else is transliterated where possible
/// (Cyrillic, Greek, CJK, compatibility forms like "№") and dropped otherwise, so the
/// payload never contains characters a bank could reject.
enum QRBillText {
    nonisolated static func isPermitted(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x20...0x7E, 0xA0...0x17F, 0x218...0x21B, 0x20AC: true
        default: false
        }
    }

    /// Line breaks are kept: callers either flatten them (address fields) or reject them
    /// (the message). Other whitespace collapses to single spaces.
    nonisolated static func sanitize(_ text: String) -> String {
        var result = ""
        var unsupported = ""

        func flushUnsupported() {
            guard !unsupported.isEmpty else { return }
            result += transliterate(unsupported)
            unsupported = ""
        }

        for character in text.precomposedStringWithCanonicalMapping {
            if character.isNewline {
                flushUnsupported()
                result.append(character)
            } else if character.isWhitespace {
                flushUnsupported()
                if !result.hasSuffix(" ") { result.append(" ") }
            } else if character.unicodeScalars.allSatisfy(isPermitted) {
                flushUnsupported()
                result.append(character)
            } else {
                unsupported.append(character)
            }
        }
        flushUnsupported()

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// One payload field: a single line of permitted characters, cut to the field's limit
    /// only after sanitizing (transliteration can lengthen text).
    nonisolated static func payloadField(_ value: String, limit: Int) -> String {
        let line = value.components(separatedBy: .newlines).joined(separator: " ")
        return String(sanitize(line).prefix(limit))
    }

    /// Transliterates a run of unsupported characters as a whole (so e.g. Chinese keeps
    /// spaces between syllables), then reduces only what still isn't permitted to ASCII
    /// (“quotes”, dashes, other diacritics) — accents the QR bill allows, like é, survive.
    nonisolated private static func transliterate(_ text: String) -> String {
        let latin = text.precomposedStringWithCompatibilityMapping
            .applyingTransform(.toLatin, reverse: false) ?? text

        var result = ""
        for character in latin.precomposedStringWithCanonicalMapping {
            if character.unicodeScalars.allSatisfy(isPermitted) {
                result.append(character)
            } else {
                let ascii = String(character).applyingTransform(StringTransform("Latin-ASCII"), reverse: false) ?? ""
                result.unicodeScalars.append(contentsOf: ascii.unicodeScalars.filter(isPermitted))
            }
        }
        return result
    }
}
