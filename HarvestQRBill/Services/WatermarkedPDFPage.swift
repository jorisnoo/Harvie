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
        watermarkPage.draw(with: box, to: context)
    }
}
