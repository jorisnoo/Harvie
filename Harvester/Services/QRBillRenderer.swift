//
//  QRBillRenderer.swift
//  Harvester
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

        // Title "Receipt"
        y = drawText(context: context, text: "Receipt", x: leftMargin, y: y, fontSize: 11, bold: true, maxWidth: maxWidth)
        y -= 8 * mmToPoints

        // Account / Payable to
        y = drawText(context: context, text: "Account / Payable to", x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
        y = drawText(context: context, text: IBANValidator.format(data.creditorIBAN), x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)
        y = drawText(context: context, text: data.creditorAddress.name, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)

        if let street = data.creditorAddress.streetName, !street.isEmpty {
            let addressLine = [street, data.creditorAddress.buildingNumber].compactMap { $0 }.joined(separator: " ")
            y = drawText(context: context, text: addressLine, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)
        }
        y = drawText(context: context, text: "\(data.creditorAddress.postalCode) \(data.creditorAddress.town)", x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)

        y -= 8 * mmToPoints

        // Reference
        if let reference = data.reference, !reference.isEmpty {
            y = drawText(context: context, text: "Reference", x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
            y = drawText(context: context, text: formatReference(reference), x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth)
            y -= 8 * mmToPoints
        }

        // Payable by
        if let debtor = data.debtorAddress {
            y = drawText(context: context, text: "Payable by", x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
            y = drawText(context: context, text: debtor.name, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth, wrap: true)
            if let street = debtor.streetName, !street.isEmpty {
                let addressLine = [street, debtor.buildingNumber].compactMap { $0 }.joined(separator: " ")
                y = drawText(context: context, text: addressLine, x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth, wrap: true)
            }
            _ = drawText(context: context, text: "\(debtor.postalCode) \(debtor.town)", x: leftMargin, y: y, fontSize: 8, bold: false, maxWidth: maxWidth, wrap: true)
        } else {
            y = drawText(context: context, text: "Payable by (name/address)", x: leftMargin, y: y, fontSize: 6, bold: true, maxWidth: maxWidth)
            drawCornerMarks(context: context, xMM: marginMM, yMM: y / mmToPoints - 20, widthMM: 52, heightMM: 20)
        }

        // Currency and Amount at bottom (with more padding)
        let bottomY: CGFloat = 15 * mmToPoints
        _ = drawText(context: context, text: "Currency", x: leftMargin, y: bottomY + 10, fontSize: 6, bold: true, maxWidth: maxWidth)
        _ = drawText(context: context, text: data.currency, x: leftMargin, y: bottomY, fontSize: 8, bold: false, maxWidth: maxWidth)

        let amountX = 25 * mmToPoints
        _ = drawText(context: context, text: "Amount", x: amountX, y: bottomY + 10, fontSize: 6, bold: true, maxWidth: maxWidth)
        if let amount = data.amount {
            _ = drawText(context: context, text: formatAmount(amount), x: amountX, y: bottomY, fontSize: 8, bold: false, maxWidth: maxWidth)
        }

        // Acceptance point (with padding from bottom edge)
        _ = drawText(context: context, text: "Acceptance point", x: leftMargin, y: 8 * mmToPoints, fontSize: 6, bold: true, maxWidth: maxWidth)
    }

    // MARK: - Payment Section (Right, 148mm wide, at bottom of A4)

    private func drawPaymentSection(context: CGContext, data: QRBillData, qrImage: CGImage) {
        let sectionStartMM = receiptWidthMM
        let leftMargin = (sectionStartMM + marginMM) * mmToPoints
        // Start from top of QR bill area (105mm from bottom, minus margin)
        var y = (qrBillHeightMM - marginMM) * mmToPoints

        // Title "Payment part"
        y = drawText(context: context, text: "Payment part", x: leftMargin, y: y, fontSize: 11, bold: true, maxWidth: 140 * mmToPoints)
        y -= 5 * mmToPoints

        // QR Code (positioned at left of payment section)
        let qrSize = qrCodeSizeMM * mmToPoints
        let qrX = leftMargin
        let qrY = y - qrSize

        context.draw(qrImage, in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))

        // Draw Swiss cross in center of QR code
        drawSwissCross(context: context, centerX: qrX + qrSize / 2, centerY: qrY + qrSize / 2)

        // Text column to the right of QR code
        let textColumnX = leftMargin + qrSize + 5 * mmToPoints
        let textColumnMaxWidth = (pageWidthMM - sectionStartMM - marginMM - qrCodeSizeMM - 10) * mmToPoints
        var textY = y - 3 * mmToPoints

        // Account / Payable to
        textY = drawText(context: context, text: "Account / Payable to", x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
        textY = drawText(context: context, text: IBANValidator.format(data.creditorIBAN), x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
        textY = drawText(context: context, text: data.creditorAddress.name, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)

        if let street = data.creditorAddress.streetName, !street.isEmpty {
            let addressLine = [street, data.creditorAddress.buildingNumber].compactMap { $0 }.joined(separator: " ")
            textY = drawText(context: context, text: addressLine, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
        }
        textY = drawText(context: context, text: "\(data.creditorAddress.postalCode) \(data.creditorAddress.town)", x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)

        textY -= 5 * mmToPoints

        // Reference
        if let reference = data.reference, !reference.isEmpty {
            textY = drawText(context: context, text: "Reference", x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            textY = drawText(context: context, text: formatReference(reference), x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
            textY -= 5 * mmToPoints
        }

        // Additional information
        if let message = data.unstructuredMessage, !message.isEmpty {
            textY = drawText(context: context, text: "Additional information", x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            textY = drawText(context: context, text: message, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth)
            textY -= 5 * mmToPoints
        }

        // Payable by
        if let debtor = data.debtorAddress {
            textY = drawText(context: context, text: "Payable by", x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            textY = drawText(context: context, text: debtor.name, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth, wrap: true)
            if let street = debtor.streetName, !street.isEmpty {
                let addressLine = [street, debtor.buildingNumber].compactMap { $0 }.joined(separator: " ")
                textY = drawText(context: context, text: addressLine, x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth, wrap: true)
            }
            _ = drawText(context: context, text: "\(debtor.postalCode) \(debtor.town)", x: textColumnX, y: textY, fontSize: 10, bold: false, maxWidth: textColumnMaxWidth, wrap: true)
        } else {
            textY = drawText(context: context, text: "Payable by (name/address)", x: textColumnX, y: textY, fontSize: 8, bold: true, maxWidth: textColumnMaxWidth)
            drawCornerMarks(context: context, xMM: textColumnX / mmToPoints, yMM: textY / mmToPoints - 25, widthMM: 65, heightMM: 25)
        }

        // Currency and Amount at bottom left of payment section (with more padding)
        let bottomY: CGFloat = 15 * mmToPoints
        _ = drawText(context: context, text: "Currency", x: leftMargin, y: bottomY + 12, fontSize: 8, bold: true, maxWidth: 50 * mmToPoints)
        _ = drawText(context: context, text: data.currency, x: leftMargin, y: bottomY, fontSize: 10, bold: false, maxWidth: 50 * mmToPoints)

        let amountX = leftMargin + 15 * mmToPoints
        _ = drawText(context: context, text: "Amount", x: amountX, y: bottomY + 12, fontSize: 8, bold: true, maxWidth: 50 * mmToPoints)
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

        // White background square
        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: centerX - halfSize, y: centerY - halfSize, width: size, height: size))

        // Black border
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(0.75)
        context.stroke(CGRect(x: centerX - halfSize, y: centerY - halfSize, width: size, height: size))

        // Swiss cross (black)
        context.setFillColor(CGColor.black)
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = " "
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
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
