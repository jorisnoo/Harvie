//
//  InvoicesViewModel.swift
//  Harvester
//

import Foundation
import SwiftUI
import SwiftData
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
    var isRefreshing = false
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

    var modelContext: ModelContext?

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
        error = nil

        // First, load from cache for instant display
        if let context = modelContext {
            loadFromCache(context: context)
        }

        // Show loading indicator only if cache is empty
        if invoices.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }

        do {
            let credentials = try await keychainService.loadHarvestCredentials()

            guard credentials.isValid else {
                hasValidCredentials = false
                error = "Please configure your Harvest API credentials in Settings."
                isLoading = false
                isRefreshing = false
                return
            }

            hasValidCredentials = true

            let fetchedInvoices = try await apiService.fetchAllInvoices(
                credentials: credentials,
                state: stateFilter
            )

            invoices = fetchedInvoices

            // Update cache
            if let context = modelContext {
                updateCache(with: fetchedInvoices, context: context)
            }
        } catch KeychainService.KeychainError.notFound {
            hasValidCredentials = false
            error = "Please configure your Harvest API credentials in Settings."
        } catch {
            // Only show error if we don't have cached data
            if invoices.isEmpty {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
        isRefreshing = false
    }

    private func loadFromCache(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedInvoice>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )

        do {
            let cached = try context.fetch(descriptor)

            // Filter by state if needed
            let filtered: [CachedInvoice]
            if let stateFilter = stateFilter {
                filtered = cached.filter { $0.stateRaw == stateFilter.rawValue }
            } else {
                filtered = cached
            }

            invoices = filtered.map { $0.toInvoice() }
        } catch {
            print("Failed to load from cache: \(error)")
        }
    }

    private func updateCache(with invoices: [Invoice], context: ModelContext) {
        // Fetch existing cached invoices
        let descriptor = FetchDescriptor<CachedInvoice>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        // Update or insert
        for invoice in invoices {
            if let cached = existingById[invoice.id] {
                cached.update(from: invoice)
            } else {
                let cached = CachedInvoice(from: invoice)
                context.insert(cached)
            }
        }

        // Save changes
        try? context.save()
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

            let appSettings: AppSettings
            do {
                appSettings = try await keychainService.loadAppSettings()
            } catch {
                appSettings = .default
            }

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

                let fileName = appSettings.generateFilename(
                    invoiceNumber: invoice.number,
                    creditorName: creditorInfo?.name ?? "",
                    clientName: invoice.client.name,
                    issueDate: invoice.issueDate
                )
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
}
