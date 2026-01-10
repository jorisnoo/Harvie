//
//  InvoicesViewModel.swift
//  Harvester
//

import Foundation
import SwiftUI
import PDFKit
import AppKit

enum InvoiceSortOption: String, CaseIterable {
    case issueDate = "Issue Date"
    case dueDate = "Due Date"
    case paidDate = "Paid Date"
}

enum SortDirection {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

@Observable
@MainActor
final class InvoicesViewModel {
    var invoices: [Invoice] = []
    var selectedInvoice: Invoice?
    var selectedInvoiceIDs: Set<Int> = []
    var isLoading = false
    var error: String?
    var stateFilter: InvoiceState? = .open
    var sortOption: InvoiceSortOption = .issueDate
    var sortDirection: SortDirection = .descending
    var hasValidCredentials = false

    // Batch export state
    var isExporting = false
    var exportProgress: Double = 0
    var exportProgressMessage: String = ""
    var exportError: String?
    var showExportSuccess = false
    var exportedCount = 0

    private let apiService = HarvestAPIService.shared
    private let keychainService = KeychainService.shared
    private let pdfService = PDFService.shared

    var sortedInvoices: [Invoice] {
        let sorted = invoices.sorted { lhs, rhs in
            let comparison: ComparisonResult
            switch sortOption {
            case .issueDate:
                comparison = lhs.issueDate.compare(rhs.issueDate)
            case .dueDate:
                comparison = lhs.dueDate.compare(rhs.dueDate)
            case .paidDate:
                let lhsDate = lhs.paidAt ?? lhs.paidDate ?? Date.distantPast
                let rhsDate = rhs.paidAt ?? rhs.paidDate ?? Date.distantPast
                comparison = lhsDate.compare(rhsDate)
            }
            return sortDirection == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
        return sorted
    }

    func loadInvoices() async {
        isLoading = true
        error = nil

        do {
            let credentials = try await keychainService.loadHarvestCredentials()

            guard credentials.isValid else {
                hasValidCredentials = false
                error = "Please configure your Harvest API credentials in Settings."
                isLoading = false
                return
            }

            hasValidCredentials = true

            let fetchedInvoices = try await apiService.fetchAllInvoices(
                credentials: credentials,
                state: stateFilter
            )

            invoices = fetchedInvoices
        } catch KeychainService.KeychainError.notFound {
            hasValidCredentials = false
            error = "Please configure your Harvest API credentials in Settings."
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadInvoices()
    }

    func getCredentials() async throws -> HarvestCredentials {
        try await keychainService.loadHarvestCredentials()
    }

    func getCreditorInfo() async throws -> CreditorInfo {
        try await keychainService.loadCreditorInfo()
    }

    var selectedInvoices: [Invoice] {
        invoices.filter { selectedInvoiceIDs.contains($0.id) }
    }

    func selectAll() {
        selectedInvoiceIDs = Set(invoices.map { $0.id })
    }

    func deselectAll() {
        selectedInvoiceIDs.removeAll()
    }

    func exportSelectedInvoices(withQRBill: Bool) async {
        let invoicesToExport = selectedInvoices
        guard !invoicesToExport.isEmpty else { return }

        // Show folder picker
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select folder to save invoices"
        panel.prompt = "Select"

        let response = await MainActor.run {
            panel.runModal()
        }

        guard response == .OK, let folderURL = panel.url else { return }

        isExporting = true
        exportProgress = 0
        exportError = nil
        exportedCount = 0

        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            let creditorInfo = withQRBill ? try await keychainService.loadCreditorInfo() : nil

            if withQRBill, let info = creditorInfo, !info.isValid {
                exportError = "Please configure your creditor information in Settings."
                isExporting = false
                return
            }

            let total = invoicesToExport.count

            for (index, invoice) in invoicesToExport.enumerated() {
                exportProgressMessage = "Exporting \(invoice.number)..."
                exportProgress = Double(index) / Double(total)

                let document: PDFDocument
                if withQRBill, let info = creditorInfo {
                    document = try await pdfService.createInvoiceWithQRBill(
                        invoice: invoice,
                        credentials: credentials,
                        creditorInfo: info
                    )
                } else {
                    let pdfURL = apiService.buildPDFURL(for: invoice, subdomain: credentials.subdomain)
                    document = try await pdfService.downloadPDF(from: pdfURL)
                }

                let fileName = generateFileName(for: invoice, creditorName: creditorInfo?.name ?? "")
                let fileURL = folderURL.appendingPathComponent(fileName)

                try await pdfService.savePDF(document, to: fileURL)
                exportedCount += 1
            }

            exportProgress = 1.0
            exportProgressMessage = "Export complete!"
            showExportSuccess = true
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    private func generateFileName(for invoice: Invoice, creditorName: String) -> String {
        let sanitizedNumber = invoice.number
            .replacingOccurrences(of: "/", with: "-")
        let sanitizedCreditor = creditorName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        if sanitizedCreditor.isEmpty {
            return "Rechnung_\(sanitizedNumber).pdf"
        }
        return "Rechnung_\(sanitizedNumber)_\(sanitizedCreditor).pdf"
    }
}
