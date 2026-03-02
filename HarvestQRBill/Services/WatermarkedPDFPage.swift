//
//  WatermarkedPDFPage.swift
//  HarvestQRBill
//

import AppKit
import PDFKit

final class WatermarkedPDFPage: PDFPage {
    private let originalPage: PDFPage
    private let text: String
    private let dateText: String?

    init(page: PDFPage, text: String, paidDate: Date?) {
        self.originalPage = page
        self.text = text
        if let paidDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            self.dateText = formatter.string(from: paidDate)
        } else {
            self.dateText = nil
        }
        super.init()
    }

    override func bounds(for box: PDFDisplayBox) -> CGRect {
        originalPage.bounds(for: box)
    }

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        // Draw the original page
        originalPage.draw(with: box, to: context)

        let pageBounds = bounds(for: box)

        // Save state and set up for watermark drawing
        context.saveGState()

        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        let centerX = pageBounds.midX
        let centerY = pageBounds.midY

        // Rotate -30° around center
        let angle: CGFloat = -.pi / 6
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: angle)

        // Main "PAID" text
        let watermarkColor = NSColor(calibratedRed: 0.2, green: 0.65, blue: 0.3, alpha: 0.18)
        let mainFont = NSFont.systemFont(ofSize: 72, weight: .bold)
        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: mainFont,
            .foregroundColor: watermarkColor,
        ]
        let mainString = text as NSString
        let mainSize = mainString.size(withAttributes: mainAttributes)
        mainString.draw(
            at: CGPoint(x: -mainSize.width / 2, y: -mainSize.height / 2),
            withAttributes: mainAttributes
        )

        // Date line below
        if let dateText {
            let dateFont = NSFont.systemFont(ofSize: 24, weight: .medium)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: watermarkColor,
            ]
            let dateString = dateText as NSString
            let dateSize = dateString.size(withAttributes: dateAttributes)
            dateString.draw(
                at: CGPoint(x: -dateSize.width / 2, y: -mainSize.height / 2 - dateSize.height - 4),
                withAttributes: dateAttributes
            )
        }

        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }
}
