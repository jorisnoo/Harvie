//
//  PDFService.swift
//  Harvester
//

import Foundation
import PDFKit

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

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config)
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

        let pdfURL = apiService.buildPDFURL(for: invoice, subdomain: credentials.subdomain)
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
            print("Failed to fetch client details: \(error)")
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
