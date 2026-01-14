//
//  QRBillRenderer.swift
//  HarvestQRBill
//

import Foundation
import PDFKit
import CoreGraphics
import AppKit

struct QRBillRenderer {
    // 1mm = 2.83465 points
    private let mmToPoints: CGFloat = 2.83465

    // A4 page dimensions (210 x 297 mm)
    private let pageWidthMM: CGFloat = 210
    private let pageHeightMM: CGFloat = 297

    // QR bill dimensions (210 x 105 mm, positioned at bottom)
    private let qrBillHeightMM: CGFloat = 105

    // Section widths
    private let receiptWidthMM: CGFloat = 62
    private let paymentWidthMM: CGFloat = 148

    // QR code size (46 x 46 mm per spec)
    private let qrCodeSizeMM: CGFloat = 46

    // Swiss cross size (7 x 7 mm per spec)
    private let swissCrossSizeMM: CGFloat = 7

    // Margins
    private let marginMM: CGFloat = 5

    // Bilingual labels (German / English)
    private enum Labels {
        static let receipt = "Empfangsschein"
        static let paymentPart = "Zahlteil"
        static let accountPayableTo = "Konto / Zahlbar an"
        static let reference = "Referenz"
        static let additionalInfo = "Zusätzliche Informationen"
        static let payableBy = "Zahlbar durch"
        static let payableByPlaceholder = "Zahlbar durch (Name/Adresse)"
        static let currency = "Währung"
        static let amount = "Betrag"
    }

    func renderQRBillPage(data: QRBillData, qrImage: CGImage) -> PDFPage? {
        let pageWidth = pageWidthMM * mmToPoints
        let pageHeight = pageHeightMM * mmToPoints
        let qrBillHeight = qrBillHeightMM * mmToPoints

        let pdfData = NSMutableData()

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPDFPage(nil)

        // White background
        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        // Draw horizontal cut line at top of QR bill section (separating from invoice content)
        drawHorizontalDashedLine(context: context, yMM: qrBillHeightMM)

        // Draw separator line between receipt and payment part
        drawVerticalDashedLine(context: context, xMM: receiptWidthMM, maxHeightMM: qrBillHeightMM)

        // Draw receipt section (left side, 62mm wide, at bottom)
        drawReceiptSection(context: context, data: data)

        // Draw payment section (right side, 148mm wide, at bottom)
        drawPaymentSection(context: context, data: data, qrImage: qrImage)

        context.endPDFPage()
        context.closePDF()

        guard let pdfDocument = PDFDocument(data: pdfData as Data),
              let page = pdfDocument.page(at: 0) else {
            return nil
        }

        return page
    }

    // MARK: - Receipt Section (Left, 62mm wide, at bottom of A4)

    private func drawReceiptSection(context: CGContext, data: QRBillData) {
        let leftMargin = marginMM * mmToPoints
        let maxWidth = (receiptWidthMM - 2 * marginMM) * mmToPoints
        // Start from top of QR bill area (105mm from bottom, minus margin)
        var y = (qrBillHeightMM - marginMM) * mmToPoints

        // Title
        y = drawText(context: context, text: Labels.receipt, x: leftMargin, y: y, fontSize: 11, bold: true, maxWidth: maxWidth)
        y -= 8 * mmToPoints

        // Account / Payable to
        y = drawText(context: context, text: Labels.accountPayableTo, x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
        y = drawText(context: context, text: IBANValidator.format(data.creditorIBAN), x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)
        y = drawText(context: context, text: data.creditorAddress.name, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)

        if let streetLine = data.creditorAddress.streetLine {
            y = drawText(context: context, text: streetLine, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)
        }
        y = drawText(context: context, text: data.creditorAddress.cityLine, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)

        y -= 8 * mmToPoints

        // Reference
        if let reference = data.reference, !reference.isEmpty {
            y = drawText(context: context, text: Labels.reference, x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
            y = drawText(context: context, text: formatReference(reference), x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)
            y -= 8 * mmToPoints
        }

        // Payable by
        if let debtor = data.debtorAddress {
            y = drawText(context: context, text: Labels.payableBy, x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
            y = drawText(context: context, text: debtor.name, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth, wrap: true)
            if let streetLine = debtor.streetLine {
                y = drawText(context: context, text: streetLine, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth, wrap: true)
            }
            y = drawText(context: context, text: debtor.cityLine, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth, wrap: true)
        } else {
            y = drawText(context: context, text: Labels.payableByPlaceholder, x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
            drawCornerMarks(context: context, xMM: marginMM, yMM: y / mmToPoints - 20, widthMM: 52, heightMM: 20)
            y -= 20 * mmToPoints
        }

        // Currency and Amount - position below debtor address with minimum bottom margin
        let minBottomY: CGFloat = 7 * mmToPoints
        let bottomY = max(minBottomY, y - 5 * mmToPoints)
        _ = drawText(context: context, text: Labels.currency, x: leftMargin, y: bottomY + 10, fontSize: 6, bold: true, maxWidth: 20 * mmToPoints)
        _ = drawText(context: context, text: data.currency, x: leftMargin, y: bottomY, fontSize: 8, bold: false, maxWidth: 20 * mmToPoints)

        let amountX = 25 * mmToPoints
        _ = drawText(context: context, text: Labels.amount, x: amountX, y: bottomY + 10, fontSize: 6, bold: true, maxWidth: 30 * mmToPoints)
        if let amount = data.amount {
            _ = drawText(context: context, text: formatAmount(amount), x: amountX, y: bottomY, fontSize: 8, bold: false, maxWidth: 30 * mmToPoints)
        }

    }

    // MARK: - Payment Section (Right, 148mm wide, at bottom of A4)

    private func drawPaymentSection(context: CGContext, data: QRBillData, qrImage: CGImage) {
        let sectionStartMM = receiptWidthMM
        let leftMargin = (sectionStartMM + marginMM) * mmToPoints
        // Start from top of QR bill area (105mm from bottom, minus margin)
        var y = (qrBillHeightMM - marginMM) * mmToPoints

        // Title "Zahlteil"
        y = drawText(context: context, text: Labels.paymentPart, x: leftMargin, y: y, fontSize: 11, bold: true, maxWidth: 140 * mmToPoints)
        y -= 5 * mmToPoints

        // QR Code (positioned at left of payment section)
        let qrSize = qrCodeSizeMM * mmToPoints
        let qrX = leftMargin
        let qrY = y - qrSize

        context.draw(qrImage, in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))

        // Draw Swiss cross in center of QR code
        drawSwissCross(context: context, centerX: qrX + qrSize / 2, centerY: qrY + qrSize / 2)

        // Text column to the right of QR code (aligned with QR code top)
        let textColumnX = leftMargin + qrSize + 5 * mmToPoints
        let textColumnMaxWidth = (pageWidthMM - sectionStartMM - marginMM - qrCodeSizeMM - 10) * mmToPoints
        var textY = y

        // Konto / Zahlbar an
        textY = drawText(context: context, text: Labels.accountPayableTo, x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
        textY = drawText(context: context, text: IBANValidator.format(data.creditorIBAN), x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
        textY = drawText(context: context, text: data.creditorAddress.name, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)

        if let streetLine = data.creditorAddress.streetLine {
            textY = drawText(context: context, text: streetLine, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
        }
        textY = drawText(context: context, text: data.creditorAddress.cityLine, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)

        textY -= 5 * mmToPoints

        // Referenz
        if let reference = data.reference, !reference.isEmpty {
            textY = drawText(context: context, text: Labels.reference, x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            textY = drawText(context: context, text: formatReference(reference), x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
            textY -= 5 * mmToPoints
        }

        // Zusätzliche Informationen
        if let message = data.unstructuredMessage, !message.isEmpty {
            textY = drawText(context: context, text: Labels.additionalInfo, x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            textY = drawText(context: context, text: message, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
            textY -= 5 * mmToPoints
        }

        // Zahlbar durch
        if let debtor = data.debtorAddress {
            textY = drawText(context: context, text: Labels.payableBy, x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            textY = drawText(context: context, text: debtor.name, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth, wrap: true)
            if let streetLine = debtor.streetLine {
                textY = drawText(context: context, text: streetLine, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth, wrap: true)
            }
            _ = drawText(context: context, text: debtor.cityLine, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth, wrap: true)
        } else {
            textY = drawText(context: context, text: Labels.payableByPlaceholder, x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            drawCornerMarks(context: context, xMM: textColumnX / mmToPoints, yMM: textY / mmToPoints - 25, widthMM: 65, heightMM: 25)
        }

        // Währung und Betrag at bottom left of payment section
        let bottomY: CGFloat = 20 * mmToPoints
        _ = drawText(context: context, text: Labels.currency, x: leftMargin, y: bottomY + 12, fontSize: 8, bold: true, maxWidth: 50 * mmToPoints)
        _ = drawText(context: context, text: data.currency, x: leftMargin, y: bottomY, fontSize: 10, bold: false, maxWidth: 50 * mmToPoints)

        let amountX = leftMargin + 15 * mmToPoints
        _ = drawText(context: context, text: Labels.amount, x: amountX, y: bottomY + 12, fontSize: 8, bold: true, maxWidth: 50 * mmToPoints)
        if let amount = data.amount {
            _ = drawText(context: context, text: formatAmount(amount), x: amountX, y: bottomY, fontSize: 10, bold: false, maxWidth: 50 * mmToPoints)
        }
    }

    // MARK: - Drawing Helpers

    private func drawHorizontalDashedLine(context: CGContext, yMM: CGFloat) {
        let y = yMM * mmToPoints
        let pageWidth = pageWidthMM * mmToPoints

        context.saveGState()
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [2, 2])
        context.move(to: CGPoint(x: 0, y: y))
        context.addLine(to: CGPoint(x: pageWidth, y: y))
        context.strokePath()
        context.restoreGState()
    }

    private func drawVerticalDashedLine(context: CGContext, xMM: CGFloat, maxHeightMM: CGFloat) {
        let x = xMM * mmToPoints
        let maxHeight = maxHeightMM * mmToPoints

        context.saveGState()
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [2, 2])
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: maxHeight))
        context.strokePath()
        context.restoreGState()
    }

    private func drawSwissCross(context: CGContext, centerX: CGFloat, centerY: CGFloat) {
        let size = swissCrossSizeMM * mmToPoints
        let halfSize = size / 2

        // Black background square
        context.setFillColor(CGColor.black)
        context.fill(CGRect(x: centerX - halfSize, y: centerY - halfSize, width: size, height: size))

        // White cross
        context.setFillColor(CGColor.white)
        let crossArmLength = size * 0.6
        let crossArmWidth = crossArmLength / 3

        // Horizontal bar
        context.fill(CGRect(
            x: centerX - crossArmLength / 2,
            y: centerY - crossArmWidth / 2,
            width: crossArmLength,
            height: crossArmWidth
        ))

        // Vertical bar
        context.fill(CGRect(
            x: centerX - crossArmWidth / 2,
            y: centerY - crossArmLength / 2,
            width: crossArmWidth,
            height: crossArmLength
        ))
    }

    private func drawCornerMarks(context: CGContext, xMM: CGFloat, yMM: CGFloat, widthMM: CGFloat, heightMM: CGFloat) {
        let x = xMM * mmToPoints
        let y = yMM * mmToPoints
        let width = widthMM * mmToPoints
        let height = heightMM * mmToPoints
        let cornerLength: CGFloat = 3 * mmToPoints

        context.saveGState()
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(0.5)

        // Bottom-left corner
        context.move(to: CGPoint(x: x, y: y + cornerLength))
        context.addLine(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: x + cornerLength, y: y))
        context.strokePath()

        // Bottom-right corner
        context.move(to: CGPoint(x: x + width - cornerLength, y: y))
        context.addLine(to: CGPoint(x: x + width, y: y))
        context.addLine(to: CGPoint(x: x + width, y: y + cornerLength))
        context.strokePath()

        // Top-right corner
        context.move(to: CGPoint(x: x + width, y: y + height - cornerLength))
        context.addLine(to: CGPoint(x: x + width, y: y + height))
        context.addLine(to: CGPoint(x: x + width - cornerLength, y: y + height))
        context.strokePath()

        // Top-left corner
        context.move(to: CGPoint(x: x + cornerLength, y: y + height))
        context.addLine(to: CGPoint(x: x, y: y + height))
        context.addLine(to: CGPoint(x: x, y: y + height - cornerLength))
        context.strokePath()

        context.restoreGState()
    }

    @discardableResult
    private func drawText(
        context: CGContext,
        text: String,
        x: CGFloat,
        y: CGFloat,
        fontSize: CGFloat,
        bold: Bool,
        maxWidth: CGFloat,
        wrap: Bool = false
    ) -> CGFloat {
        let font = bold ?
            NSFont.boldSystemFont(ofSize: fontSize) :
            NSFont.systemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = wrap ? .byWordWrapping : .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attributedString.length),
            nil,
            CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
            nil
        )

        let textHeight = suggestedSize.height
        let textRect = CGRect(x: x, y: y - textHeight, width: maxWidth, height: textHeight)

        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)

        context.saveGState()
        CTFrameDraw(frame, context)
        context.restoreGState()

        return y - textHeight - 2
    }

    private func formatAmount(_ amount: Decimal) -> String {
        CurrencyFormatter.formatDecimal(amount, groupingSeparator: " ")
    }

    private func formatReference(_ reference: String) -> String {
        var formatted = ""
        for (index, char) in reference.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted.append(" ")
            }
            formatted.append(char)
        }
        return formatted
    }
}
