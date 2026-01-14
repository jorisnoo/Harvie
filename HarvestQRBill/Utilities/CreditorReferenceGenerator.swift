//
//  CreditorReferenceGenerator.swift
//  HarvestQRBill
//

import Foundation

struct CreditorReferenceGenerator {
    static func generate(from invoiceNumber: String) -> String {
        let cleaned = invoiceNumber
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        let reference = String(cleaned.prefix(21))
        let checkDigits = calculateCheckDigits(reference: reference)

        return "RF\(checkDigits)\(reference)"
    }

    static func validate(_ reference: String) -> Bool {
        let cleaned = reference
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard cleaned.hasPrefix("RF"),
              cleaned.count >= 5,
              cleaned.count <= 25 else {
            return false
        }

        let rearranged = String(cleaned.dropFirst(4)) + String(cleaned.prefix(4))
        let numericString = Mod97Calculator.convertToNumeric(rearranged)

        return Mod97Calculator.calculate(numericString) == 1
    }

    private static func calculateCheckDigits(reference: String) -> String {
        let numericReference = Mod97Calculator.convertToNumeric(reference)
        let rfNumeric = numericReference + "271500"
        let remainder = Mod97Calculator.calculate(rfNumeric)
        let checkDigits = 98 - remainder

        return String(format: "%02d", checkDigits)
    }
}
