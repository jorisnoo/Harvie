import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import Harvie

@Suite("Printed page margins")
@MainActor
struct MarginFilledPDFPageTests {
    private let margin = TemplatePDFService.pageMargin
    private let dark = CGColor(srgbRed: 0.06, green: 0.06, blue: 0.1, alpha: 1)

    @Test func darkContentCarriesIntoTheMargins() throws {
        let height = TemplatePDFService.a4Height
        // Page 1 is dark down to its bottom margin; page 2 is dark from its top margin
        // down to the middle, then blank where the QR bill would go.
        let document = try makeDocument(pages: [
            CGRect(x: 0, y: margin, width: TemplatePDFService.a4Width, height: height - margin),
            CGRect(x: 0, y: height / 2, width: TemplatePDFService.a4Width, height: height / 2 - margin),
        ])

        let filled = MarginFilledPDFPage.fillingMargins(of: document, margin: margin)

        let first = try #require(filled.page(at: 0))
        let second = try #require(filled.page(at: 1))
        #expect(brightness(of: first, atY: margin / 2) < 0.2)
        #expect(brightness(of: second, atY: height - margin / 2) < 0.2)
        #expect(brightness(of: second, atY: margin / 2) > 0.95)
    }

    @Test func lightPagesAreLeftAlone() throws {
        let document = try makeDocument(pages: [.zero, .zero])
        let filled = MarginFilledPDFPage.fillingMargins(of: document, margin: margin)
        #expect(filled.page(at: 0)?.isKind(of: MarginFilledPDFPage.self) == false)
        #expect(filled.page(at: 1)?.isKind(of: MarginFilledPDFPage.self) == false)
    }

    /// A4 pages, white with one dark rectangle each (none for `.zero`).
    private func makeDocument(pages darkRects: [CGRect]) throws -> PDFDocument {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: TemplatePDFService.a4Width, height: TemplatePDFService.a4Height)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        for rect in darkRects {
            context.beginPDFPage(nil)
            context.setFillColor(.white)
            context.fill(mediaBox)
            context.setFillColor(dark)
            context.fill(rect)
            context.endPDFPage()
        }
        context.closePDF()
        return try #require(PDFDocument(data: data as Data))
    }

    /// Brightness (0–1) near the left edge of `page`, `y` points up from the bottom.
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
