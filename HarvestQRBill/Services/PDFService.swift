//
//  PDFService.swift
//  HarvestQRBill
//

import AppKit
import Foundation
import os.log
import PDFKit

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "PDF")

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
    private let sessionDelegate = CertificatePinningDelegate(
        pinnedDomains: ["harvestapp.com"]
    )

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

    func applyPaidMark(
        to document: PDFDocument,
        watermarkPage: PDFPage,
        excludingLastPage: Bool
    ) {
        let lastIndex = document.pageCount - 1
        let endIndex = excludingLastPage ? lastIndex : document.pageCount
        for i in 0..<endIndex {
            guard let page = document.page(at: i) else { continue }
            let watermarked = WatermarkedPDFPage(page: page, watermarkPage: watermarkPage)
            document.removePage(at: i)
            document.insert(watermarked, at: i)
        }
    }

    private func renderAndApplyPaidMark(
        to document: PDFDocument,
        invoice: Invoice,
        language: TemplateLanguage,
        paidMarkStyle: PaidMarkStyle,
        excludingLastPage: Bool
    ) async throws {
        guard invoice.state == .paid && paidMarkStyle.enabled else { return }

        let text = language.paidMark
        let dateText: String?
        if paidMarkStyle.showDate, let paidDate = invoice.effectivePaidDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            dateText = formatter.string(from: paidDate)
        } else {
            dateText = nil
        }

        let watermarkPage = try await TemplatePDFService.shared.renderWatermarkPage(
            text: text, dateText: dateText, css: paidMarkStyle.css
        )
        applyPaidMark(to: document, watermarkPage: watermarkPage, excludingLastPage: excludingLastPage)
    }

    func savePDF(_ document: PDFDocument, to url: URL) throws {
        guard document.write(to: url) else {
            throw PDFError.saveFailed
        }
    }

    @MainActor
    func generateQRBillPage(
        invoice: Invoice,
        creditorInfo: CreditorInfo,
        debtorAddress: StructuredAddress?,
        language: TemplateLanguage = .en,
        labelOverrides: [String: [String: String]]? = nil
    ) throws -> PDFPage {
        let qrBillService = QRBillService()
        let qrBillRenderer = QRBillRenderer(labels: language.resolvedQRBillLabels(overrides: labelOverrides))

        let qrBillData = try qrBillService.createQRBillData(
            invoice: invoice,
            creditorInfo: creditorInfo,
            debtorAddress: debtorAddress,
            language: language,
            labelOverrides: labelOverrides
        )

        guard let qrImage = qrBillService.generateQRCodeImage(from: qrBillData) else {
            throw PDFError.qrBillGenerationFailed
        }

        guard let page = qrBillRenderer.renderQRBillPage(data: qrBillData, qrImage: qrImage) else {
            throw PDFError.qrBillGenerationFailed
        }

        return page
    }

    func createInvoiceWithQRBill(
        invoice: Invoice,
        credentials: HarvestCredentials,
        creditorInfo: CreditorInfo,
        language: TemplateLanguage = .en,
        labelOverrides: [String: [String: String]]? = nil,
        paidMarkStyle: PaidMarkStyle = .default
    ) async throws -> PDFDocument {
        let pdfURL = try HarvestAPIService.shared.buildPDFURL(for: invoice, subdomain: credentials.subdomain)
        let basePDF = try await downloadPDF(from: pdfURL)

        let debtorAddress = await fetchDebtorAddress(
            clientId: invoice.client.id,
            clientName: invoice.client.name,
            credentials: credentials
        )

        return try await attachQRBillAndPaidMark(
            to: basePDF, invoice: invoice, creditorInfo: creditorInfo,
            debtorAddress: debtorAddress, language: language,
            labelOverrides: labelOverrides, paidMarkStyle: paidMarkStyle
        )
    }

    func createInvoiceFromTemplate(
        invoice: Invoice,
        template: InvoiceTemplate,
        creditorInfo: CreditorInfo,
        clientAddress: String? = nil,
        credentials: HarvestCredentials? = nil,
        language: TemplateLanguage = .en,
        labelOverrides: [String: [String: String]]? = nil,
        paidMarkStyle: PaidMarkStyle = .default,
        columnVisibility: ColumnVisibility = .default
    ) async throws -> PDFDocument {
        // Fetch client once and reuse for both address and debtor
        var resolvedClientAddress = clientAddress
        var fetchedClient: Client?
        if let credentials {
            fetchedClient = try? await HarvestAPIService.shared.fetchClient(id: invoice.client.id, credentials: credentials)
            if resolvedClientAddress == nil {
                resolvedClientAddress = fetchedClient?.address
            }
        }

        let logoDataURI = await LogoStorage.dataURI()

        var context = TemplateContext.from(
            invoice: invoice,
            creditorInfo: creditorInfo,
            clientAddress: resolvedClientAddress,
            logoDataURI: logoDataURI
        ).toDictionary()
        context["labels"] = language.resolvedLabels(overrides: labelOverrides)

        let basePDF = try await TemplatePDFService.shared.renderTemplate(
            template: template,
            context: context,
            columnVisibility: columnVisibility
        )

        // Build debtor address from already-fetched client
        let debtorAddress: StructuredAddress?
        if credentials != nil {
            debtorAddress = buildDebtorAddress(from: fetchedClient, clientName: invoice.client.name)
        } else {
            debtorAddress = StructuredAddress(
                name: invoice.client.name,
                streetName: nil,
                buildingNumber: nil,
                postalCode: "",
                town: "",
                country: "CH"
            )
        }

        return try await attachQRBillAndPaidMark(
            to: basePDF, invoice: invoice, creditorInfo: creditorInfo,
            debtorAddress: debtorAddress, language: language,
            labelOverrides: labelOverrides, paidMarkStyle: paidMarkStyle
        )
    }

    private func attachQRBillAndPaidMark(
        to document: PDFDocument,
        invoice: Invoice,
        creditorInfo: CreditorInfo,
        debtorAddress: StructuredAddress?,
        language: TemplateLanguage,
        labelOverrides: [String: [String: String]]?,
        paidMarkStyle: PaidMarkStyle
    ) async throws -> PDFDocument {
        guard QRBillService.isCurrencySupported(invoice.currency) else {
            try await renderAndApplyPaidMark(
                to: document, invoice: invoice, language: language,
                paidMarkStyle: paidMarkStyle, excludingLastPage: false
            )
            return document
        }

        let qrBillPage = try await MainActor.run {
            try generateQRBillPage(
                invoice: invoice,
                creditorInfo: creditorInfo,
                debtorAddress: debtorAddress,
                language: language,
                labelOverrides: labelOverrides
            )
        }

        let result = appendQRBill(to: document, qrBillPage: qrBillPage)

        try await renderAndApplyPaidMark(
            to: result, invoice: invoice, language: language,
            paidMarkStyle: paidMarkStyle, excludingLastPage: true
        )

        return result
    }

    private func fetchDebtorAddress(
        clientId: Int,
        clientName: String,
        credentials: HarvestCredentials
    ) async -> StructuredAddress? {
        let apiService = HarvestAPIService.shared

        do {
            let client = try await apiService.fetchClient(id: clientId, credentials: credentials)
            return buildDebtorAddress(from: client, clientName: clientName)
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

    private func buildDebtorAddress(from client: Client?, clientName: String) -> StructuredAddress {
        if let addressString = client?.address, !addressString.isEmpty {
            return parseAddress(addressString, name: clientName)
        }

        return StructuredAddress(
            name: clientName,
            streetName: nil,
            buildingNumber: nil,
            postalCode: "",
            town: "",
            country: "CH"
        )
    }

    #if DEBUG
    func createDemoInvoiceWithQRBill(
        invoice: Invoice,
        creditorInfo: CreditorInfo,
        paidMarkStyle: PaidMarkStyle = .default
    ) async throws -> PDFDocument {
        let demoPDF = await MainActor.run {
            createDemoInvoicePDF(invoice: invoice, creditorInfo: creditorInfo)
        }

        guard QRBillService.isCurrencySupported(invoice.currency) else {
            return demoPDF
        }

        let debtorAddress = StructuredAddress(
            name: invoice.client.name,
            streetName: "Musterstrasse",
            buildingNumber: "1",
            postalCode: "8000",
            town: "Zürich",
            country: "CH"
        )

        let qrBillPage = try await MainActor.run {
            try generateQRBillPage(
                invoice: invoice,
                creditorInfo: creditorInfo,
                debtorAddress: debtorAddress
            )
        }

        let document = appendQRBill(to: demoPDF, qrBillPage: qrBillPage)

        try await renderAndApplyPaidMark(
            to: document, invoice: invoice, language: .de,
            paidMarkStyle: paidMarkStyle, excludingLastPage: true
        )

        return document
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
    #endif

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
