//
//  WatermarkedPDFPage.swift
//  HarvestQRBill
//

import PDFKit

final class WatermarkedPDFPage: PDFPage {
    private let originalPage: PDFPage
    private let watermarkPage: PDFPage

    init(page: PDFPage, watermarkPage: PDFPage) {
        self.originalPage = page
        self.watermarkPage = watermarkPage
        super.init()
    }

    override func bounds(for box: PDFDisplayBox) -> CGRect {
        originalPage.bounds(for: box)
    }

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        originalPage.draw(with: box, to: context)

        // Align watermark bounds to the original page so any mediaBox
        // differences (origin offset, slight size mismatch) don't shift the overlay.
        let target = originalPage.bounds(for: box)
        let source = watermarkPage.bounds(for: box)

        context.saveGState()
        context.translateBy(x: target.origin.x - source.origin.x,
                            y: target.origin.y - source.origin.y)
        context.scaleBy(x: target.width / source.width,
                        y: target.height / source.height)
        watermarkPage.draw(with: box, to: context)
        context.restoreGState()
    }
}
