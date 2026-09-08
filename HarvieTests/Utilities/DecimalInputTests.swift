import Foundation
import Testing
@testable import Harvie

@Suite("Monetary input")
@MainActor
struct DecimalInputTests {
    @Test func parsesCompleteLocalizedNumbers() {
        #expect(DecimalInput.parse("-25.50", locale: Locale(identifier: "en_US")) == Decimal(string: "-25.50"))
        #expect(DecimalInput.parse("1,234.56", locale: Locale(identifier: "en_US")) == Decimal(string: "1234.56"))
        #expect(DecimalInput.parse("1.234,56", locale: Locale(identifier: "de_DE")) == Decimal(string: "1234.56"))
        #expect(DecimalInput.parse("1’234.56", locale: Locale(identifier: "de_CH")) == Decimal(string: "1234.56"))
    }

    @Test(arguments: ["abc12", "12abc", "1,23.45", "1.234,56", "--25", "", "1.2.3"])
    func rejectsMalformedNumbers(text: String) {
        #expect(DecimalInput.parse(text, locale: Locale(identifier: "en_US")) == nil)
    }

    @Test func preservesCentsInElectronicInvoices() {
        for currency in ["CHF", "EUR", "USD"] {
            #expect(CurrencyFormatter.rounded(Decimal(string: "10.02")!, currency: currency) == Decimal(string: "10.02"))
            #expect(CurrencyFormatter.rounded(Decimal(string: "10.025")!, currency: currency) == Decimal(string: "10.03"))
        }
    }
}
