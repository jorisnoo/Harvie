//
//  CreditorReferenceGeneratorTests.swift
//  HarvieTests
//

import Testing
@testable import Harvie

@Suite("Creditor Reference Generator")
struct CreditorReferenceGeneratorTests {

    @Test("Generates RF-prefixed reference")
    func generateRFPrefix() {
        let reference = CreditorReferenceGenerator.generate(from: "INV001")
        #expect(reference.hasPrefix("RF"))
    }

    @Test("Generated reference has valid length (5-25 chars)")
    func generatedReferenceLength() {
        let reference = CreditorReferenceGenerator.generate(from: "INV001")
        #expect(reference.count >= 5)
        #expect(reference.count <= 25)
    }

    @Test("Generated reference is valid")
    func generatedReferenceIsValid() {
        let reference = CreditorReferenceGenerator.generate(from: "INV12345")
        #expect(CreditorReferenceGenerator.validate(reference))
    }

    @Test("Truncates long invoice numbers to 21 characters")
    func truncatesLongInvoiceNumber() {
        let longNumber = "ABCDEFGHIJKLMNOPQRSTUVWXYZ12345"
        let reference = CreditorReferenceGenerator.generate(from: longNumber)
        // RF + 2 check digits + 21 chars = 25 max
        #expect(reference.count == 25)
    }

    @Test("Cleans special characters from invoice number")
    func cleansSpecialCharacters() {
        let reference = CreditorReferenceGenerator.generate(from: "INV-001/2024")
        #expect(CreditorReferenceGenerator.validate(reference))
        #expect(!reference.contains("-"))
        #expect(!reference.contains("/"))
    }

    @Test("Converts to uppercase")
    func convertsToUppercase() {
        let reference = CreditorReferenceGenerator.generate(from: "inv001")
        #expect(reference == reference.uppercased())
    }

    @Test("Validates correct RF reference")
    func validatesCorrectReference() {
        // Generate a known valid reference
        let reference = CreditorReferenceGenerator.generate(from: "TEST123")
        #expect(CreditorReferenceGenerator.validate(reference))
    }

    @Test("Invalid reference without RF prefix fails")
    func invalidWithoutRFPrefix() {
        #expect(!CreditorReferenceGenerator.validate("NOPREFIX123"))
    }

    @Test("Reference too short fails validation")
    func referenceTooShort() {
        #expect(!CreditorReferenceGenerator.validate("RF18"))
    }

    @Test("Reference too long fails validation")
    func referenceTooLong() {
        let longRef = "RF18" + String(repeating: "A", count: 22)
        #expect(!CreditorReferenceGenerator.validate(longRef))
    }

    @Test("Invalid check digits fails validation")
    func invalidCheckDigits() {
        #expect(!CreditorReferenceGenerator.validate("RF00INVALID"))
    }

    @Test("Validation handles spaces")
    func validationHandlesSpaces() {
        let reference = CreditorReferenceGenerator.generate(from: "TEST")
        let withSpaces = reference.enumerated().map { index, char in
            index > 0 && index % 4 == 0 ? " \(char)" : "\(char)"
        }.joined()

        #expect(CreditorReferenceGenerator.validate(withSpaces))
    }

    @Test("Validation is case-insensitive")
    func validationCaseInsensitive() {
        let reference = CreditorReferenceGenerator.generate(from: "TEST")
        #expect(CreditorReferenceGenerator.validate(reference.lowercased()))
    }
}
