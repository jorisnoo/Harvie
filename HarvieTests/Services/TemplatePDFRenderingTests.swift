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

    @Test func darkTemplatesReachThePaperEdgeAtPageBreaks() async throws {
        let htmlURL = try #require(Bundle.main.url(forResource: "neon-noir", withExtension: "html"))
        let cssURL = try #require(Bundle.main.url(forResource: "neon-noir", withExtension: "css"))
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
        try #require(document.pageCount > 1)

        // The bottom margin of a full page takes the template's background…
        let firstPage = try #require(document.page(at: 0))
        #expect(brightness(of: firstPage, atY: TemplatePDFService.pageMargin / 2) < 0.2)
        // …but stays white below the last page's content, where the QR bill goes.
        let lastPage = try #require(document.page(at: document.pageCount - 1))
        #expect(brightness(of: lastPage, atY: TemplatePDFService.pageMargin / 2) > 0.95)
    }

    /// Brightness (0–1) at the left edge of `page`, `y` points up from the bottom.
    private func brightness(of page: PDFPage, atY y: CGFloat) -> CGFloat {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width), height = Int(bounds.height)
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            page.draw(with: .mediaBox, to: context)
        }
        let offset = ((height - 1 - Int(y)) * width + 10) * 4
        return CGFloat(Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) / (3 * 255)
    }
}
