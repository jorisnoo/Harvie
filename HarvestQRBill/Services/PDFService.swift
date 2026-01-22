//
//  PDFService.swift
//  HarvestQRBill
//

import AppKit
import Foundation
import os.log
import PDFKit

nonisolated(unsafe) private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "PDF")

/// Delegate that implements certificate pinning for Harvest domains
private final class HarvestPDFURLSessionDelegate: NSObject, URLSessionDelegate {
    private let pinnedDomains = ["harvestapp.com"]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              pinnedDomains.contains(where: { challenge.protectionSpace.host.hasSuffix($0) })
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Validate the certificate chain
        let policies = [SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)]
        SecTrustSetPolicies(serverTrust, policies as CFArray)

        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if isValid {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            #if DEBUG
            logger.error("Certificate validation failed for \(challenge.protectionSpace.host)")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

actor PDFService {
    static let shared = PDFService()

    enum PDFError: Error, LocalizedError {
        case downloadFailed
        case invalidPDF
        case saveFailed
        case qrBillGenerationFailed

        var errorDescription: String? {
            switch self {
            case .downloadFailed:
                return "Failed to download the PDF from Harvest."
            case .invalidPDF:
                return "The downloaded file is not a valid PDF."
            case .saveFailed:
                return "Failed to save the PDF file."
            case .qrBillGenerationFailed:
                return "Failed to generate the QR bill."
            }
        }
    }

    private let session: URLSession
    private let sessionDelegate = HarvestPDFURLSessionDelegate()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }

    func downloadPDF(from url: URL) async throws -> PDFDocument {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PDFError.downloadFailed
        }

        guard let document = PDFDocument(data: data) else {
            throw PDFError.invalidPDF
        }

        return document
    }

    func appendQRBill(to document: PDFDocument, qrBillPage: PDFPage) -> PDFDocument {
        document.insert(qrBillPage, at: document.pageCount)
        return document
    }

    func savePDF(_ document: PDFDocument, to url: URL) throws {
        guard document.write(to: url) else {
            throw PDFError.saveFailed
        }
    }

    func createInvoiceWithQRBill(
        invoice: Invoice,
        credentials: HarvestCredentials,
        creditorInfo: CreditorInfo
    ) async throws -> PDFDocument {
        let apiService = HarvestAPIService.shared

        let pdfURL = try apiService.buildPDFURL(for: invoice, subdomain: credentials.subdomain)
        let invoicePDF = try await downloadPDF(from: pdfURL)

        // Fetch client details to get address for debtor info
        let debtorAddress = await fetchDebtorAddress(
            clientId: invoice.client.id,
            clientName: invoice.client.name,
            credentials: credentials
        )

        let qrBillPage = try await MainActor.run {
            let qrBillService = QRBillService()
            let qrBillRenderer = QRBillRenderer()

            let qrBillData = try qrBillService.createQRBillData(
                invoice: invoice,
                creditorInfo: creditorInfo,
                debtorAddress: debtorAddress
            )

            guard let qrImage = qrBillService.generateQRCodeImage(from: qrBillData) else {
                throw PDFError.qrBillGenerationFailed
            }

            guard let page = qrBillRenderer.renderQRBillPage(data: qrBillData, qrImage: qrImage) else {
                throw PDFError.qrBillGenerationFailed
            }

            return page
        }

        return appendQRBill(to: invoicePDF, qrBillPage: qrBillPage)
    }

    private func fetchDebtorAddress(
        clientId: Int,
        clientName: String,
        credentials: HarvestCredentials
    ) async -> StructuredAddress? {
        let apiService = HarvestAPIService.shared

        do {
            let client = try await apiService.fetchClient(id: clientId, credentials: credentials)

            if let addressString = client.address, !addressString.isEmpty {
                return parseAddress(addressString, name: clientName)
            }
        } catch {
            #if DEBUG
            logger.debug("Failed to fetch client details: \(error.localizedDescription)")
            #endif
        }

        // Fallback: just use the client name without address
        return StructuredAddress(
            name: clientName,
            streetName: nil,
            buildingNumber: nil,
            postalCode: "",
            town: "",
            country: "CH"
        )
    }

    func createDemoInvoiceWithQRBill(
        invoice: Invoice,
        creditorInfo: CreditorInfo
    ) async throws -> PDFDocument {
        let debtorAddress = StructuredAddress(
            name: invoice.client.name,
            streetName: "Musterstrasse",
            buildingNumber: "1",
            postalCode: "8000",
            town: "Zürich",
            country: "CH"
        )

        let (demoPDF, qrBillPage) = try await MainActor.run {
            // Create a simple placeholder PDF for demo mode
            let pdf = createDemoInvoicePDF(invoice: invoice, creditorInfo: creditorInfo)

            let qrBillService = QRBillService()
            let qrBillRenderer = QRBillRenderer()

            let qrBillData = try qrBillService.createQRBillData(
                invoice: invoice,
                creditorInfo: creditorInfo,
                debtorAddress: debtorAddress
            )

            guard let qrImage = qrBillService.generateQRCodeImage(from: qrBillData) else {
                throw PDFError.qrBillGenerationFailed
            }

            guard let page = qrBillRenderer.renderQRBillPage(data: qrBillData, qrImage: qrImage) else {
                throw PDFError.qrBillGenerationFailed
            }

            return (pdf, page)
        }

        return appendQRBill(to: demoPDF, qrBillPage: qrBillPage)
    }

    @MainActor
    private func createDemoInvoicePDF(invoice: Invoice, creditorInfo: CreditorInfo) -> PDFDocument {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4

        let pdfData = NSMutableData()
        var mediaBox = pageRect
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return PDFDocument()
        }

        context.beginPDFPage(nil)

        // Set up graphics context for AppKit drawing
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        // Draw content (coordinate system starts at bottom-left)
        let titleFont = NSFont.systemFont(ofSize: 24, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
        let titleString = creditorInfo.name as NSString
        titleString.draw(at: CGPoint(x: 50, y: pageRect.height - 60), withAttributes: titleAttributes)

        let invoiceFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        let invoiceAttributes: [NSAttributedString.Key: Any] = [.font: invoiceFont]
        let invoiceString = "Rechnung \(invoice.number)" as NSString
        invoiceString.draw(at: CGPoint(x: 50, y: pageRect.height - 100), withAttributes: invoiceAttributes)

        let bodyFont = NSFont.systemFont(ofSize: 12)
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]
        let clientString = invoice.client.name as NSString
        clientString.draw(at: CGPoint(x: 50, y: pageRect.height - 140), withAttributes: bodyAttributes)

        if let subject = invoice.subject {
            let subjectString = subject as NSString
            subjectString.draw(at: CGPoint(x: 50, y: pageRect.height - 160), withAttributes: bodyAttributes)
        }

        var yPosition = pageRect.height - 220
        let labelFont = NSFont.systemFont(ofSize: 10, weight: .medium)
        let grayColor = NSColor.gray
        let labelAttributes: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: grayColor]

        ("Beschreibung" as NSString).draw(at: CGPoint(x: 50, y: yPosition), withAttributes: labelAttributes)
        ("Menge" as NSString).draw(at: CGPoint(x: 350, y: yPosition), withAttributes: labelAttributes)
        ("Betrag" as NSString).draw(at: CGPoint(x: 480, y: yPosition), withAttributes: labelAttributes)

        yPosition -= 25

        if let lineItems = invoice.lineItems {
            for item in lineItems {
                let desc = (item.description ?? "Service") as NSString
                desc.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: bodyAttributes)

                let qty = String(format: "%.1f", Double(truncating: item.quantity as NSNumber)) as NSString
                qty.draw(at: CGPoint(x: 350, y: yPosition), withAttributes: bodyAttributes)

                let amount = String(format: "%.2f", Double(truncating: item.amount as NSNumber)) as NSString
                amount.draw(at: CGPoint(x: 480, y: yPosition), withAttributes: bodyAttributes)

                yPosition -= 20
            }
        }

        yPosition -= 30
        let totalFont = NSFont.systemFont(ofSize: 14, weight: .bold)
        let totalAttributes: [NSAttributedString.Key: Any] = [.font: totalFont]

        if let taxAmount = invoice.taxAmount {
            let taxString = String(format: "MwSt (8.1%%): CHF %.2f", Double(truncating: taxAmount as NSNumber)) as NSString
            taxString.draw(at: CGPoint(x: 350, y: yPosition), withAttributes: bodyAttributes)
            yPosition -= 25
        }

        let totalString = String(format: "Total: CHF %.2f", Double(truncating: invoice.amount as NSNumber)) as NSString
        totalString.draw(at: CGPoint(x: 350, y: yPosition), withAttributes: totalAttributes)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let issueDateString = "Rechnungsdatum: \(dateFormatter.string(from: invoice.issueDate))" as NSString
        issueDateString.draw(at: CGPoint(x: 50, y: 150), withAttributes: bodyAttributes)

        let dueDateString = "Zahlbar bis: \(dateFormatter.string(from: invoice.dueDate))" as NSString
        dueDateString.draw(at: CGPoint(x: 50, y: 130), withAttributes: bodyAttributes)

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()

        return PDFDocument(data: pdfData as Data) ?? PDFDocument()
    }

    private func parseAddress(_ address: String, name: String) -> StructuredAddress {
        // Harvest address is typically multi-line:
        // Street 123
        // 8000 Zürich
        // Switzerland
        let lines = address.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var streetName: String?
        var buildingNumber: String?
        var postalCode = ""
        var town = ""
        var country = "CH"

        if lines.count >= 1 {
            // First line is typically street + number
            let streetLine = lines[0]
            let parts = streetLine.components(separatedBy: " ")
            if let lastPart = parts.last, lastPart.rangeOfCharacter(from: .decimalDigits) != nil,
               parts.count > 1 {
                buildingNumber = lastPart
                streetName = parts.dropLast().joined(separator: " ")
            } else {
                streetName = streetLine
            }
        }

        if lines.count >= 2 {
            // Second line is typically postal code + city
            let cityLine = lines[1]
            let parts = cityLine.components(separatedBy: " ")
            if let firstPart = parts.first, firstPart.rangeOfCharacter(from: .decimalDigits) != nil {
                postalCode = firstPart
                town = parts.dropFirst().joined(separator: " ")
            } else {
                town = cityLine
            }
        }

        if lines.count >= 3 {
            // Third line could be country
            let countryLine = lines[2]
            if countryLine.count == 2 {
                country = countryLine.uppercased()
            } else {
                // Map common country names to codes
                let countryMap = [
                    "switzerland": "CH",
                    "schweiz": "CH",
                    "suisse": "CH",
                    "germany": "DE",
                    "deutschland": "DE",
                    "austria": "AT",
                    "österreich": "AT",
                    "france": "FR",
                    "italy": "IT",
                    "italia": "IT"
                ]
                country = countryMap[countryLine.lowercased()] ?? "CH"
            }
        }

        return StructuredAddress(
            name: name,
            streetName: streetName,
            buildingNumber: buildingNumber,
            postalCode: postalCode,
            town: town,
            country: country
        )
    }
}
