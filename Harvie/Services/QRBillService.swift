//
//  QRBillService.swift
//  Harvie
//

import Foundation
import CoreImage

struct QRBillService {
    nonisolated static func isCurrencySupported(_ currency: String) -> Bool {
        ["CHF", "EUR"].contains(currency.uppercased())
    }

    static func shouldIncludeQRBill(for invoice: Invoice) -> Bool {
        isCurrencySupported(invoice.currency) && invoice.dueAmount > 0 && invoice.state != .paid
    }

    enum ValidationError: Error, LocalizedError, Equatable {
        case invalidIBAN
        case qrIBANNotSupported
        case invalidCreditorAddress
        case invalidAmount
        case invalidCurrency
        case invalidReference
        case messageTooLong

        var errorDescription: String? {
            switch self {
            case .invalidIBAN:
                return Strings.Errors.invalidIBAN
            case .qrIBANNotSupported:
                return Strings.Errors.qrIBANNotSupported
            case .invalidCreditorAddress:
                return Strings.Errors.invalidCreditorAddress
            case .invalidAmount:
                return Strings.Errors.invalidAmount
            case .invalidCurrency:
                return Strings.Errors.invalidCurrency
            case .invalidReference:
                return Strings.Errors.invalidReference
            case .messageTooLong:
                return Strings.Errors.messageTooLong
            }
        }
    }

    func createQRBillData(
        invoice: Invoice,
        creditorInfo: CreditorInfo,
        debtorAddress: StructuredAddress? = nil,
        language: TemplateLanguage = .en,
        labelOverrides: [String: [String: String]]? = nil
    ) throws -> QRBillData {
        guard IBANValidator.isSwissIBAN(creditorInfo.iban), IBANValidator.validate(creditorInfo.iban) else {
            throw ValidationError.invalidIBAN
        }

        // QR-IBAN requires QRR reference type, which we don't support (SCOR only)
        if IBANValidator.isQRIBAN(creditorInfo.iban) {
            throw ValidationError.qrIBANNotSupported
        }

        guard creditorInfo.isValid else {
            throw ValidationError.invalidCreditorAddress
        }

        let currency = invoice.currency.uppercased()
        guard ["CHF", "EUR"].contains(currency) else {
            throw ValidationError.invalidCurrency
        }

        let generated = CreditorReferenceGenerator.generate(from: invoice.number)
        let reference = CreditorReferenceGenerator.validate(generated)
            ? generated : CreditorReferenceGenerator.generate(from: String(invoice.id))

        // Text is restricted to the QR bill's character set up front, so the slip
        // renders exactly what the payload encodes and validation sees final lengths.
        let debtor = debtorAddress?.sanitized()
        let message = "\(language.resolvedQRBillLabels(overrides: labelOverrides).invoice) \(invoice.number)"

        let data = QRBillData(
            creditorIBAN: creditorInfo.iban.replacingOccurrences(of: " ", with: "").uppercased(),
            creditorAddress: creditorInfo.structuredAddress.sanitized(),
            amount: invoice.dueAmount,
            currency: currency,
            // The spec requires postal code and town when a debtor is present; an
            // incomplete address (e.g. client fetch failed) would make scanners reject
            // the code. Omit the debtor instead — the renderer draws the blank field.
            debtorAddress: debtor?.isValid == true ? debtor : nil,
            reference: reference,
            unstructuredMessage: QRBillText.sanitize(message),
            billingInfo: nil
        )
        if let error = validate(data).first { throw error }
        return data
    }

    func generateQRCodeImage(from data: QRBillData, size: CGFloat = 500) -> CGImage? {
        guard validate(data).isEmpty else { return nil }
        let payload = data.generatePayload()

        guard let payloadData = payload.data(using: .utf8) else {
            return nil
        }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(payloadData, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        // The generator adds a one-module quiet zone; the 46 mm size excludes it.
        guard let generated = filter.outputImage else {
            return nil
        }
        let outputImage = generated.cropped(to: generated.extent.insetBy(dx: 1, dy: 1))

        // Scale by a whole factor with nearest-neighbour sampling so every module stays a
        // crisp square; the renderer then draws the image at exactly 46 x 46 mm.
        let scale = max(1, (size / outputImage.extent.width).rounded(.up))
        let scaledImage = outputImage
            .samplingNearest()
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }

    private static let minAmount: Decimal = 0.01
    private static let maxAmount: Decimal = 999_999_999.99
    private static let maxMessageLength = 140

    func validate(_ data: QRBillData) -> [ValidationError] {
        var errors: [ValidationError] = []

        if !IBANValidator.isSwissIBAN(data.creditorIBAN) || !IBANValidator.validate(data.creditorIBAN) {
            errors.append(.invalidIBAN)
        }

        if IBANValidator.isQRIBAN(data.creditorIBAN) {
            errors.append(.qrIBANNotSupported)
        }

        if !data.creditorAddress.isValid {
            errors.append(.invalidCreditorAddress)
        }

        if let amount = data.amount {
            if amount < Self.minAmount || amount > Self.maxAmount {
                errors.append(.invalidAmount)
            }
        }

        if !["CHF", "EUR"].contains(data.currency) {
            errors.append(.invalidCurrency)
        }

        if !CreditorReferenceGenerator.validate(data.reference ?? "") {
            errors.append(.invalidReference)
        }

        // Combined message and billing info must not exceed 140 characters
        let messageLength = (data.unstructuredMessage ?? "").count + (data.billingInfo ?? "").count
        if messageLength > Self.maxMessageLength ||
            (data.unstructuredMessage ?? "").rangeOfCharacter(from: .newlines) != nil ||
            (data.billingInfo ?? "").rangeOfCharacter(from: .newlines) != nil {
            errors.append(.messageTooLong)
        }

        return errors
    }
}
