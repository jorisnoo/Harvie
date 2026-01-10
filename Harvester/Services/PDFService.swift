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
        creditorInfo: CreditorInfo,
        debtorAddress: StructuredAddress? = nil
    ) async throws -> PDFDocument {
        let apiService = HarvestAPIService.shared

        let pdfURL = apiService.buildPDFURL(for: invoice, subdomain: credentials.subdomain)
        let invoicePDF = try await downloadPDF(from: pdfURL)

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
}
