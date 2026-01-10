//
//  QRBillService.swift
//  Harvester
//

import Foundation
import CoreImage

struct QRBillService {
    enum ValidationError: Error, LocalizedError {
        case invalidIBAN
        case invalidCreditorAddress
        case invalidAmount
        case invalidCurrency
        case invalidReference

        var errorDescription: String? {
            switch self {
            case .invalidIBAN:
                return "Invalid IBAN format."
            case .invalidCreditorAddress:
                return "Creditor address is incomplete."
            case .invalidAmount:
                return "Invalid amount."
            case .invalidCurrency:
                return "Currency must be CHF or EUR."
            case .invalidReference:
                return "Invalid creditor reference format."
            }
        }
    }

    func createQRBillData(
        invoice: Invoice,
        creditorInfo: CreditorInfo,
        debtorAddress: StructuredAddress? = nil
    ) throws -> QRBillData {
        guard IBANValidator.validate(creditorInfo.iban) else {
            throw ValidationError.invalidIBAN
        }

        guard creditorInfo.isValid else {
            throw ValidationError.invalidCreditorAddress
        }

        let currency = invoice.currency.uppercased()
        guard ["CHF", "EUR"].contains(currency) else {
            throw ValidationError.invalidCurrency
        }

        let reference = CreditorReferenceGenerator.generate(from: invoice.number)

        return QRBillData(
            creditorIBAN: creditorInfo.iban.replacingOccurrences(of: " ", with: "").uppercased(),
            creditorAddress: creditorInfo.structuredAddress,
            amount: invoice.dueAmount,
            currency: currency,
            debtorAddress: debtorAddress,
            reference: reference,
            unstructuredMessage: "Invoice \(invoice.number)",
            billingInfo: nil
        )
    }

    func generateQRCodeImage(from data: QRBillData, size: CGFloat = 500) -> CGImage? {
        let payload = data.generatePayload()

        guard let payloadData = payload.data(using: .utf8) else {
            return nil
        }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(payloadData, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }

    func validate(_ data: QRBillData) -> [ValidationError] {
        var errors: [ValidationError] = []

        if !IBANValidator.validate(data.creditorIBAN) {
            errors.append(.invalidIBAN)
        }

        if !data.creditorAddress.isValid {
            errors.append(.invalidCreditorAddress)
        }

        if let amount = data.amount, amount < 0 {
            errors.append(.invalidAmount)
        }

        if !["CHF", "EUR"].contains(data.currency) {
            errors.append(.invalidCurrency)
        }

        if let reference = data.reference,
           !reference.isEmpty,
           !CreditorReferenceGenerator.validate(reference) {
            errors.append(.invalidReference)
        }

        return errors
    }
}
