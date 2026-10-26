//
//  MarginFilledPDFPage.swift
//  Harvie
//

import PDFKit

/// A printed template page with its `@page` margins painted in the colour of the content
/// beside them. WebKit never paints backgrounds into page margins, so a dark template would
/// otherwise show white bands at every page break.
final class MarginFilledPDFPage: PDFPage {
    private nonisolated(unsafe) let originalPage: PDFPage
    private let fills: [(rect: CGRect, color: CGColor)]

    nonisolated init(page: PDFPage, fills: [(rect: CGRect, color: CGColor)]) {
        self.originalPage = page
        self.fills = fills
        super.init()
    }

    nonisolated override func bounds(for box: PDFDisplayBox) -> CGRect {
        originalPage.bounds(for: box)
    }

    nonisolated override func draw(with box: PDFDisplayBox, to context: CGContext) {
        originalPage.draw(with: box, to: context)
        context.saveGState()
        for fill in fills {
            context.setFillColor(fill.color)
            context.fill(fill.rect)
        }
        context.restoreGState()
    }

    /// Fills the top margin of every page but the first and the bottom margin of every page,
    /// wherever the content meets that margin in one solid, non-white colour at both edges.
    /// Light templates and the blank space after the last line are left as they are.
    static func fillingMargins(of document: PDFDocument, margin: CGFloat) -> PDFDocument {
        let filled = PDFDocument()
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            var fills: [(rect: CGRect, color: CGColor)] = []

            if let pixels = PagePixels(page: page) {
                let bottom = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: margin)
                if let color = pixels.edgeColor(atY: margin + 2, besideBandAtY: margin / 2) {
                    fills.append((bottom, color))
                }
                if index > 0 {
                    let top = CGRect(x: bounds.minX, y: bounds.maxY - margin, width: bounds.width, height: margin)
                    let height = bounds.height
                    if let color = pixels.edgeColor(atY: height - margin - 3, besideBandAtY: height - margin / 2) {
                        fills.append((top, color))
                    }
                }
            }

            filled.insert(fills.isEmpty ? page : MarginFilledPDFPage(page: page, fills: fills), at: filled.pageCount)
        }
        return filled
    }
}

/// A one-point-per-pixel rendering of a page on white, for sampling colours.
private struct PagePixels {
    private let data: [UInt8]
    private let width: Int
    private let height: Int

    init?(page: PDFPage) {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width.rounded(.up))
        let height = Int(bounds.height.rounded(.up))
        guard width > 2, height > 2 else { return nil }

        var data = [UInt8](repeating: 255, count: width * height * 4)
        let rendered = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            page.draw(with: .mediaBox, to: context)
            return true
        }
        guard rendered else { return nil }
        self.data = data
        self.width = width
        self.height = height
    }

    /// The colour at both side edges of row `y` when they match and aren't white, and the
    /// margin row `bandY` is still blank at those edges. `y` counts up from the bottom.
    func edgeColor(atY y: CGFloat, besideBandAtY bandY: CGFloat) -> CGColor? {
        // Inset from the sides: the last column is only partly covered on fractional page widths.
        let leftX = 3, rightX = width - 4
        let left = pixel(x: leftX, y: y), right = pixel(x: rightX, y: y)
        guard left == right, !left.isWhite,
              pixel(x: leftX, y: bandY).isWhite, pixel(x: rightX, y: bandY).isWhite else { return nil }
        return CGColor(srgbRed: CGFloat(left.red) / 255, green: CGFloat(left.green) / 255, blue: CGFloat(left.blue) / 255, alpha: 1)
    }

    private struct RGB: Equatable {
        let red, green, blue: UInt8
        var isWhite: Bool { red > 250 && green > 250 && blue > 250 }
    }

    private func pixel(x: Int, y: CGFloat) -> RGB {
        // Bitmap rows run top to bottom; page coordinates bottom to top.
        let row = min(max(height - 1 - Int(y), 0), height - 1)
        let offset = (row * width + x) * 4
        return RGB(red: data[offset], green: data[offset + 1], blue: data[offset + 2])
    }
}
