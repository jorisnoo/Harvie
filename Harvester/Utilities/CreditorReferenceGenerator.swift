//
//  CreditorReferenceGenerator.swift
//  Harvester
//

import Foundation

struct CreditorReferenceGenerator {
    static func generate(from invoiceNumber: String) -> String {
        let cleanedNumber = invoiceNumber
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        let reference = String(cleanedNumber.prefix(21))

        let checkDigits = calculateCheckDigits(reference: reference)

        return "RF\(checkDigits)\(reference)"
    }

    static func validate(_ reference: String) -> Bool {
        let cleanedReference = reference
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard cleanedReference.hasPrefix("RF"),
              cleanedReference.count >= 5,
              cleanedReference.count <= 25 else {
            return false
        }

        let rearranged = String(cleanedReference.dropFirst(4)) + String(cleanedReference.prefix(4))

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

    private static func calculateCheckDigits(reference: String) -> String {
        let numericReference = convertToNumeric(reference)

        let rfNumeric = numericReference + "271500"

        let remainder = mod97(rfNumeric)
        let checkDigits = 98 - remainder

        return String(format: "%02d", checkDigits)
    }

    private static func convertToNumeric(_ string: String) -> String {
        var numericString = ""

        for char in string {
            if char.isNumber {
                numericString.append(char)
            } else if char.isLetter {
                let value = Int(char.asciiValue!) - Int(Character("A").asciiValue!) + 10
                numericString.append(String(value))
            }
        }

        return numericString
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
