//
//  IBANValidator.swift
//  Harvester
//

import Foundation

struct IBANValidator {
    static func validate(_ iban: String) -> Bool {
        let cleanedIBAN = iban.replacingOccurrences(of: " ", with: "").uppercased()

        guard cleanedIBAN.count >= 5 && cleanedIBAN.count <= 34 else {
            return false
        }

        let countryCode = String(cleanedIBAN.prefix(2))
        guard countryCode.allSatisfy({ $0.isLetter }) else {
            return false
        }

        let checkDigits = String(cleanedIBAN.dropFirst(2).prefix(2))
        guard checkDigits.allSatisfy({ $0.isNumber }) else {
            return false
        }

        let rearranged = String(cleanedIBAN.dropFirst(4)) + String(cleanedIBAN.prefix(4))

        var numericString = ""
        for char in rearranged {
            if char.isNumber {
                numericString.append(char)
            } else if char.isLetter {
                let value = Int(char.asciiValue!) - Int(Character("A").asciiValue!) + 10
                numericString.append(String(value))
            }
        }

        return mod97(numericString) == 1
    }

    static func isSwissIBAN(_ iban: String) -> Bool {
        let cleanedIBAN = iban.replacingOccurrences(of: " ", with: "").uppercased()
        return cleanedIBAN.hasPrefix("CH") || cleanedIBAN.hasPrefix("LI")
    }

    static func isQRIBAN(_ iban: String) -> Bool {
        let cleanedIBAN = iban.replacingOccurrences(of: " ", with: "").uppercased()

        guard isSwissIBAN(cleanedIBAN), cleanedIBAN.count >= 9 else {
            return false
        }

        let iid = String(cleanedIBAN.dropFirst(4).prefix(5))

        guard let iidNumber = Int(iid) else {
            return false
        }

        return iidNumber >= 30000 && iidNumber <= 31999
    }

    static func format(_ iban: String) -> String {
        let cleanedIBAN = iban.replacingOccurrences(of: " ", with: "").uppercased()
        var formatted = ""

        for (index, char) in cleanedIBAN.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted.append(" ")
            }
            formatted.append(char)
        }

        return formatted
    }

    private static func mod97(_ numericString: String) -> Int {
        var remainder = 0

        for char in numericString {
            guard let digit = Int(String(char)) else { continue }
            remainder = (remainder * 10 + digit) % 97
        }

        return remainder
    }
}
