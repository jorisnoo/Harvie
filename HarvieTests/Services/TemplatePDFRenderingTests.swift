import Foundation
import PDFKit
import Testing
@testable import Harvie

@Suite("Template PDF rendering")
@MainActor
struct TemplatePDFRenderingTests {
    @Test func longInvoicesAreSplitIntoA4Pages() async throws {
        let htmlURL = try #require(Bundle.main.url(forResource: "classic", withExtension: "html"))
        let cssURL = try #require(Bundle.main.url(forResource: "classic", withExtension: "css"))
        var context = TemplateContext.sampleDictionary()
        context["labels"] = TemplateLanguage.en.labels
        context["lineItems"] = (1...40).map { index -> [String: Any] in
            ["description": "Line item \(index)", "quantity": Decimal(1), "unitPrice": Decimal(100),
             "amount": Decimal(100), "kind": "Service", "taxed": true]
        }

        let template = try String(contentsOf: htmlURL, encoding: .utf8)
        let css = try String(contentsOf: cssURL, encoding: .utf8)
        let document = try await TemplatePDFService.shared.renderPDF(
            html: TemplateEngine.render(template, with: context), css: css
        )

        #expect(document.pageCount > 1)
        for index in 0..<document.pageCount {
            let size = try #require(document.page(at: index)).bounds(for: .mediaBox).size
            #expect(abs(size.width - TemplatePDFService.a4Width) < 1)
            #expect(abs(size.height - TemplatePDFService.a4Height) < 1)
        }
    }
}
