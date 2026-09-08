import Foundation
import Testing
@testable import Harvie

@Suite("Template accounting and escaping")
@MainActor
struct TemplateAccountingTests {
    @Test func escapesTextAndAttributeValues() {
        let value = "\"><style>.summary{display:none}</style>&'"
        let html = TemplateEngine.render("<div title=\"{{name}}\">{{name}}</div>", with: ["name": value])
        #expect(!html.contains("<style>"))
        #expect(html.contains("&quot;&gt;&lt;style&gt;"))
        #expect(html.contains("&amp;&#39;"))
        let fallback = TemplateEngine.render("{{name | currency}}", with: ["name": value])
        #expect(!fallback.contains("<style>"))
        let markdown = TemplateEngine.render("{{name | markdown}}", with: ["name": "**safe** <img src=x>"])
        #expect(markdown.contains("<strong>safe</strong>"))
        #expect(!markdown.contains("<img"))
    }

    @Test func preservesSubtotalAndRemainingBalance() throws {
        let context = TemplateContext.from(invoice: TestDocuments.invoice(amount: 105, dueAmount: 65, tax2Amount: 5),
                                           creditorInfo: TestDocuments.creditor).toDictionary()
        let invoice = try #require(context["invoice"] as? [String: Any])
        #expect(invoice["subtotal"] as? Decimal == 100)
        #expect(invoice["dueAmount"] as? Decimal == 65)
        #expect(invoice["amountSettled"] as? Decimal == 40)
        #expect(invoice["hasPayments"] as? Bool == true)
        let estimate = TemplateContext.from(estimate: TestDocuments.estimate(), creditorInfo: TestDocuments.creditor).toDictionary()
        #expect((estimate["invoice"] as? [String: Any])?["hasPayments"] as? Bool == false)
    }

    @Test(arguments: ["classic", "modern", "minimal", "funky", "neon-noir"])
    func templatesShowSecondaryTaxAndBalance(name: String) throws {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "html"))
        let template = try String(contentsOf: url, encoding: .utf8)
        var context = TemplateContext.from(invoice: TestDocuments.invoice(amount: 105, dueAmount: 65, tax2Amount: 5),
                                          creditorInfo: TestDocuments.creditor).toDictionary()
        context["labels"] = TemplateLanguage.en.labels
        let html = TemplateEngine.render(template, with: context)
        #expect(html.contains("Secondary tax"))
        #expect(html.contains("5.00"))
        #expect(html.contains("Balance due"))
        #expect(html.contains("65.00"))
        #expect(html.contains("-40.00"))
    }
}
