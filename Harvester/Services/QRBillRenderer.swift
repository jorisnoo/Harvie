//
//  QRBillRenderer.swift
//  Harvester
//

import Foundation
import PDFKit
import CoreGraphics
import AppKit

struct QRBillRenderer {
    private let mmToPoints: CGFloat = 2.83465

    private let pageWidth: CGFloat = 210
    private let pageHeight: CGFloat = 105

    private let receiptWidth: CGFloat = 62
    private let paymentWidth: CGFloat = 148

    private let qrCodeSize: CGFloat = 46
    private let swissCrossSize: CGFloat = 7

    private let margin: CGFloat = 5
    private let sectionSpacing: CGFloat = 9

    func renderQRBillPage(data: QRBillData, qrImage: CGImage) -> PDFPage? {
        let pageWidthPts = pageWidth * mmToPoints
        let pageHeightPts = pageHeight * mmToPoints

        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return nil
        }

        let mediaBox = CGRect(x: 0, y: 0, width: pageWidthPts, height: pageHeightPts)
        context.beginPDFPage([kCGPDFContextMediaBox as String: NSValue(rect: mediaBox)] as CFDictionary)

        drawBackground(context: context, pageWidth: pageWidthPts, pageHeight: pageHeightPts)
        drawSeparatorLine(context: context, x: receiptWidth * mmToPoints, pageHeight: pageHeightPts)
        drawReceiptSection(context: context, data: data, pageHeight: pageHeightPts)
        drawPaymentSection(context: context, data: data, qrImage: qrImage, pageHeight: pageHeightPts)

        context.endPDFPage()
        context.closePDF()

        guard let pdfDocument = PDFDocument(data: pdfData as Data),
              let page = pdfDocument.page(at: 0) else {
            return nil
        }

        return page
    }

    private func drawBackground(context: CGContext, pageWidth: CGFloat, pageHeight: CGFloat) {
        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
    }

    private func drawSeparatorLine(context: CGContext, x: CGFloat, pageHeight: CGFloat) {
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [2, 2])
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: pageHeight))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }

    private func drawReceiptSection(context: CGContext, data: QRBillData, pageHeight: CGFloat) {
        let marginPts = margin * mmToPoints
        var yPosition = pageHeight - marginPts

        yPosition = drawText(
            context: context,
            text: "Receipt",
            x: marginPts,
            y: yPosition,
            fontSize: 11,
            bold: true
        )

        yPosition -= sectionSpacing * mmToPoints

        yPosition = drawText(context: context, text: "Account / Payable to", x: marginPts, y: yPosition, fontSize: 6, bold: true)
        yPosition = drawText(context: context, text: IBANValidator.format(data.creditorIBAN), x: marginPts, y: yPosition, fontSize: 8, bold: false)
        yPosition = drawText(context: context, text: data.creditorAddress.name, x: marginPts, y: yPosition, fontSize: 8, bold: false)

        if let street = data.creditorAddress.streetName {
            let addressLine = data.creditorAddress.buildingNumber != nil ?
                "\(street) \(data.creditorAddress.buildingNumber!)" : street
            yPosition = drawText(context: context, text: addressLine, x: marginPts, y: yPosition, fontSize: 8, bold: false)
        }

        yPosition = drawText(
            context: context,
            text: "\(data.creditorAddress.postalCode) \(data.creditorAddress.town)",
            x: marginPts,
            y: yPosition,
            fontSize: 8,
            bold: false
        )

        yPosition -= sectionSpacing * mmToPoints

        if let reference = data.reference, !reference.isEmpty {
            yPosition = drawText(context: context, text: "Reference", x: marginPts, y: yPosition, fontSize: 6, bold: true)
            yPosition = drawText(context: context, text: formatReference(reference), x: marginPts, y: yPosition, fontSize: 8, bold: false)
            yPosition -= sectionSpacing * mmToPoints
        }

        if let debtor = data.debtorAddress {
            yPosition = drawText(context: context, text: "Payable by", x: marginPts, y: yPosition, fontSize: 6, bold: true)
            yPosition = drawText(context: context, text: debtor.name, x: marginPts, y: yPosition, fontSize: 8, bold: false)

            if let street = debtor.streetName {
                let addressLine = debtor.buildingNumber != nil ? "\(street) \(debtor.buildingNumber!)" : street
                yPosition = drawText(context: context, text: addressLine, x: marginPts, y: yPosition, fontSize: 8, bold: false)
            }

            yPosition = drawText(
                context: context,
                text: "\(debtor.postalCode) \(debtor.town)",
                x: marginPts,
                y: yPosition,
                fontSize: 8,
                bold: false
            )
        } else {
            yPosition = drawText(context: context, text: "Payable by (name/address)", x: marginPts, y: yPosition, fontSize: 6, bold: true)
            drawEmptyBox(context: context, x: marginPts, y: yPosition - 25 * mmToPoints, width: 52 * mmToPoints, height: 25 * mmToPoints)
        }

        let currencyY: CGFloat = 15 * mmToPoints
        _ = drawText(context: context, text: "Currency", x: marginPts, y: currencyY, fontSize: 6, bold: true)
        _ = drawText(context: context, text: data.currency, x: marginPts, y: currencyY - 8, fontSize: 8, bold: false)

        let amountX: CGFloat = 25 * mmToPoints
        _ = drawText(context: context, text: "Amount", x: amountX, y: currencyY, fontSize: 6, bold: true)
        if let amount = data.amount {
            _ = drawText(context: context, text: formatAmount(amount), x: amountX, y: currencyY - 8, fontSize: 8, bold: false)
        } else {
            drawEmptyBox(context: context, x: amountX, y: currencyY - 15, width: 30 * mmToPoints, height: 10 * mmToPoints)
        }

        _ = drawText(context: context, text: "Acceptance point", x: marginPts, y: marginPts + 8, fontSize: 6, bold: true)
    }

    private func drawPaymentSection(context: CGContext, data: QRBillData, qrImage: CGImage, pageHeight: CGFloat) {
        let marginPts = margin * mmToPoints
        let paymentStartX = receiptWidth * mmToPoints + marginPts
        var yPosition = pageHeight - marginPts

        yPosition = drawText(context: context, text: "Payment part", x: paymentStartX, y: yPosition, fontSize: 11, bold: true)

        yPosition -= sectionSpacing * mmToPoints

        let qrSizePts = qrCodeSize * mmToPoints
        let qrY = yPosition - qrSizePts
        context.draw(qrImage, in: CGRect(x: paymentStartX, y: qrY, width: qrSizePts, height: qrSizePts))

        drawSwissCross(
            context: context,
            centerX: paymentStartX + qrSizePts / 2,
            centerY: qrY + qrSizePts / 2,
            size: swissCrossSize * mmToPoints
        )

        let textStartX = paymentStartX + qrSizePts + 5 * mmToPoints
        var textY = pageHeight - marginPts - 12 * mmToPoints

        textY = drawText(context: context, text: "Currency", x: paymentStartX, y: 15 * mmToPoints, fontSize: 8, bold: true)
        _ = drawText(context: context, text: data.currency, x: paymentStartX, y: 15 * mmToPoints - 10, fontSize: 10, bold: false)

        let amountX = paymentStartX + 20 * mmToPoints
        _ = drawText(context: context, text: "Amount", x: amountX, y: 15 * mmToPoints, fontSize: 8, bold: true)
        if let amount = data.amount {
            _ = drawText(context: context, text: formatAmount(amount), x: amountX, y: 15 * mmToPoints - 10, fontSize: 10, bold: false)
        } else {
            drawEmptyBox(context: context, x: amountX, y: 15 * mmToPoints - 18, width: 40 * mmToPoints, height: 15 * mmToPoints)
        }

        textY = drawText(context: context, text: "Account / Payable to", x: textStartX, y: textY, fontSize: 8, bold: true)
        textY = drawText(context: context, text: IBANValidator.format(data.creditorIBAN), x: textStartX, y: textY, fontSize: 10, bold: false)
        textY = drawText(context: context, text: data.creditorAddress.name, x: textStartX, y: textY, fontSize: 10, bold: false)

        if let street = data.creditorAddress.streetName {
            let addressLine = data.creditorAddress.buildingNumber != nil ?
                "\(street) \(data.creditorAddress.buildingNumber!)" : street
            textY = drawText(context: context, text: addressLine, x: textStartX, y: textY, fontSize: 10, bold: false)
        }

        textY = drawText(
            context: context,
            text: "\(data.creditorAddress.postalCode) \(data.creditorAddress.town)",
            x: textStartX,
            y: textY,
            fontSize: 10,
            bold: false
        )

        textY -= sectionSpacing * mmToPoints

        if let reference = data.reference, !reference.isEmpty {
            textY = drawText(context: context, text: "Reference", x: textStartX, y: textY, fontSize: 8, bold: true)
            textY = drawText(context: context, text: formatReference(reference), x: textStartX, y: textY, fontSize: 10, bold: false)
            textY -= sectionSpacing * mmToPoints
        }

        if let message = data.unstructuredMessage, !message.isEmpty {
            textY = drawText(context: context, text: "Additional information", x: textStartX, y: textY, fontSize: 8, bold: true)
            textY = drawText(context: context, text: message, x: textStartX, y: textY, fontSize: 10, bold: false)
            textY -= sectionSpacing * mmToPoints
        }

        if let debtor = data.debtorAddress {
            textY = drawText(context: context, text: "Payable by", x: textStartX, y: textY, fontSize: 8, bold: true)
            textY = drawText(context: context, text: debtor.name, x: textStartX, y: textY, fontSize: 10, bold: false)

            if let street = debtor.streetName {
                let addressLine = debtor.buildingNumber != nil ? "\(street) \(debtor.buildingNumber!)" : street
                textY = drawText(context: context, text: addressLine, x: textStartX, y: textY, fontSize: 10, bold: false)
            }

            _ = drawText(
                context: context,
                text: "\(debtor.postalCode) \(debtor.town)",
                x: textStartX,
                y: textY,
                fontSize: 10,
                bold: false
            )
        } else {
            textY = drawText(context: context, text: "Payable by (name/address)", x: textStartX, y: textY, fontSize: 8, bold: true)
            drawEmptyBox(context: context, x: textStartX, y: textY - 25 * mmToPoints, width: 65 * mmToPoints, height: 25 * mmToPoints)
        }
    }

    private func drawSwissCross(context: CGContext, centerX: CGFloat, centerY: CGFloat, size: CGFloat) {
        let outerSize = size
        let innerSize = size * 0.6
        let barWidth = innerSize / 3
        let barLength = innerSize

        context.setFillColor(CGColor.white)
        context.fill(CGRect(
            x: centerX - outerSize / 2,
            y: centerY - outerSize / 2,
            width: outerSize,
            height: outerSize
        ))

        context.setStrokeColor(CGColor.black)
        context.setLineWidth(0.5)
        context.stroke(CGRect(
            x: centerX - outerSize / 2,
            y: centerY - outerSize / 2,
            width: outerSize,
            height: outerSize
        ))

        context.setFillColor(CGColor.black)

        context.fill(CGRect(
            x: centerX - barLength / 2,
            y: centerY - barWidth / 2,
            width: barLength,
            height: barWidth
        ))

        context.fill(CGRect(
            x: centerX - barWidth / 2,
            y: centerY - barLength / 2,
            width: barWidth,
            height: barLength
        ))
    }

    private func drawEmptyBox(context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(0.5)

        let cornerSize: CGFloat = 3

        context.move(to: CGPoint(x: x, y: y + cornerSize))
        context.addLine(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: x + cornerSize, y: y))
        context.strokePath()

        context.move(to: CGPoint(x: x + width - cornerSize, y: y))
        context.addLine(to: CGPoint(x: x + width, y: y))
        context.addLine(to: CGPoint(x: x + width, y: y + cornerSize))
        context.strokePath()

        context.move(to: CGPoint(x: x + width, y: y + height - cornerSize))
        context.addLine(to: CGPoint(x: x + width, y: y + height))
        context.addLine(to: CGPoint(x: x + width - cornerSize, y: y + height))
        context.strokePath()

        context.move(to: CGPoint(x: x + cornerSize, y: y + height))
        context.addLine(to: CGPoint(x: x, y: y + height))
        context.addLine(to: CGPoint(x: x, y: y + height - cornerSize))
        context.strokePath()
    }

    @discardableResult
    private func drawText(
        context: CGContext,
        text: String,
        x: CGFloat,
        y: CGFloat,
        fontSize: CGFloat,
        bold: Bool
    ) -> CGFloat {
        let font = bold ?
            NSFont.boldSystemFont(ofSize: fontSize) :
            NSFont.systemFont(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        context.textMatrix = .identity

        let textHeight = fontSize * 1.2
        context.textPosition = CGPoint(x: x, y: y - textHeight)
        CTLineDraw(line, context)

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
