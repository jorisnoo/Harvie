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

    @Test func leavesMissingOptionalsOutOfTheContext() throws {
        let context = TemplateContext.from(invoice: TestDocuments.invoice(), creditorInfo: TestDocuments.creditor).toDictionary()
        let invoice = try #require(context["invoice"] as? [String: Any])
        let creditor = try #require(context["creditor"] as? [String: Any])
        #expect(invoice["discount"] == nil)
        #expect(invoice["tax2Amount"] == nil)
        #expect(creditor["logo"] == nil)
        #expect(TemplateEngine.render("{{#if invoice.discount}}x{{/if}}[{{invoice.discount}}]", with: context) == "[]")
    }

    @Test func totalHoursCountsOnlyTimeBasedLines() throws {
        let date = Date(timeIntervalSince1970: 1_788_220_800)
        let items = [
            LineItem(id: 1, kind: "Service", description: "Design", quantity: 8, unitPrice: 100, amount: 800,
                     taxed: false, taxed2: false, project: nil),
            LineItem(id: 2, kind: "Product", description: "Hosting", quantity: 12, unitPrice: 10, amount: 120,
                     taxed: false, taxed2: false, project: nil),
            LineItem(id: 3, kind: "Consulting", description: "Workshop", quantity: 2.5, unitPrice: 200, amount: 500,
                     taxed: false, taxed2: false, project: nil)
        ]
        let invoice = Invoice(id: 1, clientKey: "fixture", number: "INV-1", amount: 1420, dueAmount: 1420,
                              currency: "CHF", state: .open, issueDate: date, dueDate: date,
                              createdAt: date, updatedAt: date, client: ClientReference(id: 1, name: "Fixture"),
                              lineItems: items)
        let context = TemplateContext.from(invoice: invoice, creditorInfo: TestDocuments.creditor).toDictionary()
        let values = try #require(context["invoice"] as? [String: Any])
        #expect(values["totalHours"] as? Decimal == Decimal(string: "10.5"))
    }
}
