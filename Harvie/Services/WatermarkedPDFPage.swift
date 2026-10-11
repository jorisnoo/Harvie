//
//  WatermarkedPDFPage.swift
//  Harvie
//

import PDFKit

final class WatermarkedPDFPage: PDFPage {
    private nonisolated(unsafe) let originalPage: PDFPage
    private nonisolated(unsafe) let watermarkPage: PDFPage

    nonisolated init(page: PDFPage, watermarkPage: PDFPage) {
        self.originalPage = page
        self.watermarkPage = watermarkPage
        super.init()
    }

    nonisolated override func bounds(for box: PDFDisplayBox) -> CGRect {
        originalPage.bounds(for: box)
    }

    nonisolated override func draw(with box: PDFDisplayBox, to context: CGContext) {
        originalPage.draw(with: box, to: context)

        // Fit the watermark into the original page with one uniform scale, centred, so
        // mediaBox differences (origin offset, other paper sizes) never distort it.
        let target = originalPage.bounds(for: box)
        let source = watermarkPage.bounds(for: box)
        guard source.width > 0, source.height > 0 else { return }
        let scale = min(target.width / source.width, target.height / source.height)

        context.saveGState()
        context.translateBy(x: target.midX - source.midX * scale,
                            y: target.midY - source.midY * scale)
        context.scaleBy(x: scale, y: scale)
        watermarkPage.draw(with: box, to: context)
        context.restoreGState()
    }
}
