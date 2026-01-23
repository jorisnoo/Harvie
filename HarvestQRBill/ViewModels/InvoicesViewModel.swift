//
//  InvoicesViewModel.swift
//  HarvestQRBill
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

enum DateFilterPeriod: String, CaseIterable {
    case month = "Month"
    case quarter = "Quarter"
    case halfYear = "Half Year"
    case year = "Year"
}

@Observable
@MainActor
final class InvoicesViewModel {
    var invoices: [Invoice] = []
    var selectedInvoice: Invoice?
    var selectedInvoiceIDs: Set<Int> = []
    var isSelectionMode = false
    var isLoading = false
    var isRefreshing = false
    var error: String?
    var stateFilter: InvoiceState? = .open
    var sortOption: InvoiceSortOption = .issueDate
    var sortDirection: SortDirection = .descending
    var filterPeriod: DateFilterPeriod = .month
    var selectedPeriod: Date?
    var hasValidCredentials = false

    private var loadInvoicesTask: Task<Void, Never>?

    var availablePeriods: [Date] {
        let calendar = Calendar.current
        let now = Date()

        switch filterPeriod {
        case .month:
            return (0..<12).compactMap { monthsAgo in
                calendar.date(byAdding: .month, value: -monthsAgo, to: now)
                    .flatMap { calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) }
            }
        case .quarter:
            return (0..<8).compactMap { quartersAgo in
                calendar.date(byAdding: .month, value: -quartersAgo * 3, to: now)
                    .flatMap { date in
                        let month = calendar.component(.month, from: date)
                        let year = calendar.component(.year, from: date)
                        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                        return calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1))
                    }
            }
        case .halfYear:
            return (0..<4).compactMap { halvesAgo in
                calendar.date(byAdding: .month, value: -halvesAgo * 6, to: now)
                    .flatMap { date in
                        let month = calendar.component(.month, from: date)
                        let year = calendar.component(.year, from: date)
                        let halfStartMonth = month <= 6 ? 1 : 7
                        return calendar.date(from: DateComponents(year: year, month: halfStartMonth, day: 1))
                    }
            }
        case .year:
            return (0..<5).compactMap { yearsAgo in
                calendar.date(byAdding: .year, value: -yearsAgo, to: now)
                    .flatMap { calendar.date(from: calendar.dateComponents([.year], from: $0)) }
            }
        }
    }

    var validSortOptions: [InvoiceSortOption] {
        switch stateFilter {
        case .draft:
            return [.issueDate]
        case .open:
            return [.issueDate, .dueDate]
        case .paid, .closed, nil:
            return InvoiceSortOption.allCases
        }
    }

    // Creditor info for export validation
    var creditorInfo: CreditorInfo = .empty

    var canExportWithQRBill: Bool {
        creditorInfo.isValid
    }

    // Batch export state
    var isExporting = false
    var exportProgress: Double = 0
    var exportProgressMessage: String = ""
    var exportError: String?
    var showExportSuccess = false
    var exportedCount = 0

    // Update state (for issue date changes and mark as sent)
    var isUpdating = false
    var updateError: String?
    var showUpdateSuccess = false
    var updatedCount = 0

    var allSelectedAreDrafts: Bool {
        guard !selectedInvoiceIDs.isEmpty else { return false }

        return selectedInvoices.allSatisfy { $0.state == .draft }
    }

    var allSelectedAreOpen: Bool {
        guard !selectedInvoiceIDs.isEmpty else { return false }

        return selectedInvoices.allSatisfy { $0.state == .open }
    }

    var modelContext: ModelContext?

    private let apiService = HarvestAPIService.shared
    private let keychainService = KeychainService.shared
    private let pdfService = PDFService.shared

    func loadSavedState() async {
        // Load creditor info for export validation
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }

        guard let settings = try? await keychainService.loadAppSettings() else { return }

        if let sortOptionRaw = settings.lastSortOption,
           let savedSortOption = InvoiceSortOption(rawValue: sortOptionRaw) {
            sortOption = savedSortOption
        }

        if let ascending = settings.lastSortAscending {
            sortDirection = ascending ? .ascending : .descending
        }

        if let filterPeriodRaw = settings.lastFilterPeriod,
           let savedFilterPeriod = DateFilterPeriod(rawValue: filterPeriodRaw) {
            filterPeriod = savedFilterPeriod
        }

        selectedPeriod = settings.lastSelectedPeriod

        if let stateFilterRaw = settings.lastStateFilter {
            stateFilter = InvoiceState(rawValue: stateFilterRaw)
        }
    }

    func reloadCreditorInfo() async {
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }
    }

    func saveState() async {
        guard var settings = try? await keychainService.loadAppSettings() else { return }

        settings.lastSortOption = sortOption.rawValue
        settings.lastSortAscending = sortDirection == .ascending
        settings.lastFilterPeriod = filterPeriod.rawValue
        settings.lastSelectedPeriod = selectedPeriod
        settings.lastStateFilter = stateFilter?.rawValue

        try? await keychainService.saveAppSettings(settings)
    }

    var sortedInvoices: [Invoice] {
        var filtered = invoices

        if let period = selectedPeriod {
            let calendar = Calendar.current
            filtered = filtered.filter { invoice in
                let dateToCheck: Date
                switch sortOption {
                case .issueDate:
                    dateToCheck = invoice.issueDate
                case .dueDate:
                    dateToCheck = invoice.dueDate
                case .paidDate:
                    dateToCheck = invoice.paidAt ?? invoice.paidDate ?? invoice.issueDate
                }
                return isDate(dateToCheck, inSamePeriodAs: period, calendar: calendar)
            }
        }

        return filtered.sorted { lhs, rhs in
            let lhsDate: Date
            let rhsDate: Date

            switch sortOption {
            case .issueDate:
                lhsDate = lhs.issueDate
                rhsDate = rhs.issueDate
            case .dueDate:
                lhsDate = lhs.dueDate
                rhsDate = rhs.dueDate
            case .paidDate:
                lhsDate = lhs.paidAt ?? lhs.paidDate ?? .distantPast
                rhsDate = rhs.paidAt ?? rhs.paidDate ?? .distantPast
            }

            return sortDirection == .ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        }
    }

    func loadInvoices() {
        loadInvoicesTask?.cancel()
        loadInvoicesTask = Task {
            await performLoadInvoices()
        }
    }

    private func performLoadInvoices() async {
        error = nil

        // Capture current state filter before any async work
        let currentStateFilter = stateFilter

        // Check for demo mode first
        let appSettings = (try? await keychainService.loadAppSettings()) ?? .default
        if appSettings.isDemoMode {
            loadDemoInvoices()
            return
        }

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
            try Task.checkCancellation()

            let credentials = try await keychainService.loadHarvestCredentials()

            guard credentials.isValid else {
                hasValidCredentials = false
                error = "Please configure your Harvest API credentials in Settings."
                isLoading = false
                isRefreshing = false
                return
            }

            hasValidCredentials = true

            try Task.checkCancellation()

            let fetchedInvoices = try await apiService.fetchAllInvoices(
                credentials: credentials,
                state: currentStateFilter
            )

            try Task.checkCancellation()

            // Verify state filter hasn't changed during the request
            guard stateFilter == currentStateFilter else {
                return
            }

            invoices = fetchedInvoices

            // Update cache
            if let context = modelContext {
                updateCache(with: fetchedInvoices, context: context)
            }
        } catch is CancellationError {
            return
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

    private func loadDemoInvoices() {
        hasValidCredentials = true
        var demoInvoices = DemoDataProvider.invoices

        // Apply state filter if set
        if let filter = stateFilter {
            demoInvoices = demoInvoices.filter { $0.state == filter }
        }

        invoices = demoInvoices
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
            if let stateFilter {
                filtered = cached.filter { $0.stateRaw == stateFilter.rawValue }
            } else {
                filtered = cached
            }

            invoices = filtered.map { $0.toInvoice() }
        } catch { }
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

    func refresh() {
        loadInvoices()
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
        selectedInvoiceIDs = Set(sortedInvoices.map { $0.id })
    }

    func deselectAll() {
        selectedInvoiceIDs.removeAll()
    }

    func toggleSelection(for invoiceID: Int) {
        if selectedInvoiceIDs.contains(invoiceID) {
            selectedInvoiceIDs.remove(invoiceID)
        } else {
            selectedInvoiceIDs.insert(invoiceID)
        }
    }

    func exitSelectionMode() {
        isSelectionMode = false
        deselectAll()
    }

    func enterSelectionMode() {
        isSelectionMode = true
    }

    func updateIssueDate(for invoiceId: Int, to date: Date) async throws {
        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.updateInvoiceIssueDate(
            invoiceId: invoiceId,
            issueDate: date,
            credentials: credentials
        )
    }

    func updateIssueDateForSelected(to date: Date) async {
        let invoicesToUpdate = selectedInvoices.filter { $0.state == .draft }
        guard !invoicesToUpdate.isEmpty else { return }

        isUpdating = true
        updateError = nil
        updatedCount = 0

        do {
            let credentials = try await keychainService.loadHarvestCredentials()

            for invoice in invoicesToUpdate {
                try await apiService.updateInvoiceIssueDate(
                    invoiceId: invoice.id,
                    issueDate: date,
                    credentials: credentials
                )
                updatedCount += 1
            }

            showUpdateSuccess = true

            loadInvoices()
        } catch {
            updateError = error.localizedDescription
        }

        isUpdating = false
    }

    func markAsSent(invoiceId: Int) async throws {
        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.markInvoiceAsSent(
            invoiceId: invoiceId,
            credentials: credentials
        )
    }

    func markSelectedAsSent() async {
        let invoicesToUpdate = selectedInvoices.filter { $0.state == .draft }
        guard !invoicesToUpdate.isEmpty else { return }

        isUpdating = true
        updateError = nil
        updatedCount = 0

        do {
            let credentials = try await keychainService.loadHarvestCredentials()

            for invoice in invoicesToUpdate {
                try await apiService.markInvoiceAsSent(
                    invoiceId: invoice.id,
                    credentials: credentials
                )
                updatedCount += 1
            }

            showUpdateSuccess = true

            loadInvoices()
        } catch {
            updateError = error.localizedDescription
        }

        isUpdating = false
    }

    func markAsDraft(invoiceId: Int) async throws {
        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.markInvoiceAsDraft(
            invoiceId: invoiceId,
            credentials: credentials
        )
    }

    func markSelectedAsDraft() async {
        let invoicesToUpdate = selectedInvoices.filter { $0.state == .open }
        guard !invoicesToUpdate.isEmpty else { return }

        isUpdating = true
        updateError = nil
        updatedCount = 0

        do {
            let credentials = try await keychainService.loadHarvestCredentials()

            for invoice in invoicesToUpdate {
                try await apiService.markInvoiceAsDraft(
                    invoiceId: invoice.id,
                    credentials: credentials
                )
                updatedCount += 1
            }

            showUpdateSuccess = true

            loadInvoices()
        } catch {
            updateError = error.localizedDescription
        }

        isUpdating = false
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
            let creditorInfo = try await keychainService.loadCreditorInfo()

            if withQRBill, !creditorInfo.isValid {
                exportError = "Please configure your creditor information in Settings."
                isExporting = false
                return
            }

            let total = invoicesToExport.count
            let appSettings = (try? await keychainService.loadAppSettings()) ?? .default

            for (index, invoice) in invoicesToExport.enumerated() {
                exportProgressMessage = "Exporting \(index + 1) of \(total): \(invoice.number)"
                exportProgress = Double(index) / Double(total)

                let document: PDFDocument
                if withQRBill {
                    document = try await pdfService.createInvoiceWithQRBill(
                        invoice: invoice,
                        credentials: credentials,
                        creditorInfo: creditorInfo
                    )
                } else {
                    let pdfURL = try apiService.buildPDFURL(for: invoice, subdomain: credentials.subdomain)
                    document = try await pdfService.downloadPDF(from: pdfURL)
                }

                let date: Date = switch sortOption {
                case .issueDate, .dueDate:
                    invoice.issueDate
                case .paidDate:
                    invoice.paidAt ?? invoice.paidDate ?? invoice.issueDate
                }

                let fileName = appSettings.generateFilename(
                    invoiceNumber: invoice.number,
                    creditorName: creditorInfo.name,
                    clientName: invoice.client.name,
                    date: date,
                    issueDate: invoice.issueDate,
                    dueDate: invoice.dueDate,
                    paidDate: invoice.paidAt ?? invoice.paidDate
                )
                let fileURL = folderURL.appendingPathComponent(fileName)

                try await pdfService.savePDF(document, to: fileURL)
                exportedCount += 1
            }

            exportProgress = 1.0
            exportProgressMessage = "Export complete!"
            showExportSuccess = true
            Analytics.pdfExported(count: exportedCount)
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    private func isDate(_ date: Date, inSamePeriodAs period: Date, calendar: Calendar) -> Bool {
        switch filterPeriod {
        case .month:
            return calendar.isDate(date, equalTo: period, toGranularity: .month)
        case .quarter:
            let dateQuarter = (calendar.component(.month, from: date) - 1) / 3
            let periodQuarter = (calendar.component(.month, from: period) - 1) / 3
            let dateYear = calendar.component(.year, from: date)
            let periodYear = calendar.component(.year, from: period)
            return dateQuarter == periodQuarter && dateYear == periodYear
        case .halfYear:
            let dateHalf = calendar.component(.month, from: date) <= 6 ? 1 : 2
            let periodHalf = calendar.component(.month, from: period) <= 6 ? 1 : 2
            let dateYear = calendar.component(.year, from: date)
            let periodYear = calendar.component(.year, from: period)
            return dateHalf == periodHalf && dateYear == periodYear
        case .year:
            return calendar.isDate(date, equalTo: period, toGranularity: .year)
        }
    }

    func formatPeriod(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        switch filterPeriod {
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        case .quarter:
            let quarter = (calendar.component(.month, from: date) - 1) / 3 + 1
            return "Q\(quarter) \(year)"
        case .halfYear:
            let half = calendar.component(.month, from: date) <= 6 ? 1 : 2
            return "H\(half) \(year)"
        case .year:
            return "\(year)"
        }
    }
}
