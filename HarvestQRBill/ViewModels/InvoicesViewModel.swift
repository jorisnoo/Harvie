//
//  InvoicesViewModel.swift
//  HarvestQRBill
//

import Foundation
import os.log
import SwiftUI
import SwiftData
import PDFKit
import AppKit
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "InvoicesVM")

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

    var defaultPeriodCount: Int {
        switch self {
        case .month: 12
        case .quarter: 8
        case .halfYear: 4
        case .year: 5
        }
    }

    func periods(count: Int? = nil) -> [Date] {
        let n = count ?? defaultPeriodCount
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .month:
            return (0..<n).compactMap { monthsAgo in
                calendar.date(byAdding: .month, value: -monthsAgo, to: now)
                    .flatMap { calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) }
            }
        case .quarter:
            return (0..<n).compactMap { quartersAgo in
                calendar.date(byAdding: .month, value: -quartersAgo * 3, to: now)
                    .flatMap { date in
                        let month = calendar.component(.month, from: date)
                        let year = calendar.component(.year, from: date)
                        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                        return calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1))
                    }
            }
        case .halfYear:
            return (0..<n).compactMap { halvesAgo in
                calendar.date(byAdding: .month, value: -halvesAgo * 6, to: now)
                    .flatMap { date in
                        let month = calendar.component(.month, from: date)
                        let year = calendar.component(.year, from: date)
                        let halfStartMonth = month <= 6 ? 1 : 7
                        return calendar.date(from: DateComponents(year: year, month: halfStartMonth, day: 1))
                    }
            }
        case .year:
            return (0..<n).compactMap { yearsAgo in
                calendar.date(byAdding: .year, value: -yearsAgo, to: now)
                    .flatMap { calendar.date(from: calendar.dateComponents([.year], from: $0)) }
            }
        }
    }

    func contains(_ date: Date, in period: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .month:
            return calendar.isDate(date, equalTo: period, toGranularity: .month)
        case .quarter:
            let dateQuarter = (calendar.component(.month, from: date) - 1) / 3
            let periodQuarter = (calendar.component(.month, from: period) - 1) / 3
            return dateQuarter == periodQuarter &&
                calendar.component(.year, from: date) == calendar.component(.year, from: period)
        case .halfYear:
            let dateHalf = calendar.component(.month, from: date) <= 6 ? 1 : 2
            let periodHalf = calendar.component(.month, from: period) <= 6 ? 1 : 2
            return dateHalf == periodHalf &&
                calendar.component(.year, from: date) == calendar.component(.year, from: period)
        case .year:
            return calendar.isDate(date, equalTo: period, toGranularity: .year)
        }
    }

    func format(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        switch self {
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

@Observable
@MainActor
final class InvoicesViewModel {
    var invoices: [Invoice] = [] {
        didSet {
            invoicesById = Dictionary(uniqueKeysWithValues: invoices.map { ($0.id, $0) })
            updateSortedInvoices()
            updateSelectedInvoice()
        }
    }
    var selectedInvoiceIDs: Set<Int> = [] {
        didSet { updateSelectedInvoice() }
    }

    private(set) var selectedInvoice: Invoice?
    var isLoading = false
    var isRefreshing = false
    var error: String?
    var stateFilter: InvoiceState? = .open
    var sortOption: InvoiceSortOption = .issueDate {
        didSet { if !isBatchUpdating { updateSortedInvoices() } }
    }
    var sortDirection: SortDirection = .descending {
        didSet { if !isBatchUpdating { updateSortedInvoices() } }
    }
    var searchText = "" {
        didSet { if !isBatchUpdating { updateSortedInvoices() } }
    }
    var filterPeriod: DateFilterPeriod = .month {
        didSet {
            availablePeriods = filterPeriod.periods()
            if !isBatchUpdating { updateSortedInvoices() }
        }
    }
    var selectedPeriod: Date? {
        didSet { if !isBatchUpdating { updateSortedInvoices() } }
    }
    var hasValidCredentials = false
    @ObservationIgnored private(set) var isInitialized = false

    @ObservationIgnored private var isBatchUpdating = false
    @ObservationIgnored private var loadInvoicesTask: Task<Void, Never>?
    @ObservationIgnored private var saveStateTask: Task<Void, Never>?

    private(set) var availablePeriods: [Date] = DateFilterPeriod.month.periods()

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

    // Creditor info and settings for export validation
    var creditorInfo: CreditorInfo = .empty
    var appSettings: AppSettings = .default
    @ObservationIgnored private(set) var invoicesById: [Int: Invoice] = [:]

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

    @ObservationIgnored var modelContext: ModelContext?

    private let apiService = HarvestAPIService.shared
    private let keychainService = KeychainService.shared
    private let pdfService = PDFService.shared

    func loadSavedState() async {
        // Load creditor info for export validation
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }

        let settings = AppSettingsStorage.load()
        appSettings = settings

        isBatchUpdating = true

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

        isBatchUpdating = false
        isInitialized = true
        updateSortedInvoices()
    }

    func reloadSettings() async {
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }
        appSettings = AppSettingsStorage.load()
    }

    func debouncedSaveState() {
        saveStateTask?.cancel()
        saveStateTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            saveState()
        }
    }

    func saveState() {
        var settings = appSettings
        settings.lastSortOption = sortOption.rawValue
        settings.lastSortAscending = sortDirection == .ascending
        settings.lastFilterPeriod = filterPeriod.rawValue
        settings.lastSelectedPeriod = selectedPeriod
        settings.lastStateFilter = stateFilter?.rawValue
        AppSettingsStorage.save(settings)
    }

    private(set) var sortedInvoices: [Invoice] = []

    private func updateSelectedInvoice() {
        let newValue: Invoice?
        if selectedInvoiceIDs.count == 1, let id = selectedInvoiceIDs.first {
            newValue = invoicesById[id]
        } else {
            newValue = nil
        }
        if selectedInvoice != newValue {
            selectedInvoice = newValue
        }
    }

    private func updateSortedInvoices() {
        var filtered = invoices

        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.number.localizedCaseInsensitiveContains(searchText) ||
                $0.client.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.subject?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

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
                return filterPeriod.contains(dateToCheck, in: period, calendar: calendar)
            }
        }

        let newSorted = filtered.sorted { lhs, rhs in
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

        if newSorted != sortedInvoices {
            sortedInvoices = newSorted
        }
    }

    func formatPeriod(_ date: Date) -> String {
        filterPeriod.format(date)
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

        #if DEBUG
        // Check for demo mode first
        if appSettings.isDemoMode {
            loadDemoInvoices()
            return
        }
        #endif

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
            Analytics.invoicesLoaded(count: fetchedInvoices.count)

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

    #if DEBUG
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
    #endif

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
        } catch {
            logger.warning("Failed to load from cache: \(error.localizedDescription)")
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
        do {
            try context.save()
        } catch {
            logger.warning("Failed to save cache: \(error.localizedDescription)")
        }
    }

    func refresh() {
        loadInvoices()
    }

    func refreshInvoices(ids: Set<Int>) {
        Task {
            await performRefreshInvoices(ids: ids)
        }
    }

    private func performRefreshInvoices(ids: Set<Int>) async {
        guard let credentials = try? await keychainService.loadHarvestCredentials() else { return }

        var fetched: [Invoice] = []

        await withTaskGroup(of: Invoice?.self) { group in
            for id in ids {
                group.addTask {
                    try? await self.apiService.fetchInvoice(id: id, credentials: credentials)
                }
            }

            for await invoice in group {
                if let invoice {
                    fetched.append(invoice)
                }
            }
        }

        var updatedInvoices = invoices
        for invoice in fetched {
            if let index = updatedInvoices.firstIndex(where: { $0.id == invoice.id }) {
                if let stateFilter, invoice.state != stateFilter {
                    updatedInvoices.remove(at: index)
                } else {
                    updatedInvoices[index] = invoice
                }
            }
        }
        invoices = updatedInvoices

        // Clean up stale selection IDs (computed property handles the rest)
        let currentIDs = Set(updatedInvoices.map(\.id))
        selectedInvoiceIDs = selectedInvoiceIDs.intersection(currentIDs)

        if let context = modelContext {
            updateCache(with: fetched, context: context)
        }
    }

    func getCredentials() async throws -> HarvestCredentials {
        try await keychainService.loadHarvestCredentials()
    }

    func getCreditorInfo() async throws -> CreditorInfo {
        try await keychainService.loadCreditorInfo()
    }

    var selectedInvoices: [Invoice] {
        selectedInvoiceIDs.compactMap { invoicesById[$0] }
    }

    func selectAll() {
        selectedInvoiceIDs = Set(sortedInvoices.map { $0.id })
    }

    func deselectAll() {
        selectedInvoiceIDs.removeAll()
    }

    func clearInvalidSelections() {
        let visibleIDs = Set(sortedInvoices.map { $0.id })
        let invalidIDs = selectedInvoiceIDs.subtracting(visibleIDs)

        if !invalidIDs.isEmpty {
            selectedInvoiceIDs.subtract(invalidIDs)
        }
    }

    func updateIssueDate(for invoiceId: Int, to date: Date) async throws {
        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.updateInvoiceIssueDate(
            invoiceId: invoiceId,
            issueDate: date,
            credentials: credentials
        )
    }

    // MARK: - Batch Operations

    private func performBatchOperation(
        on invoices: [Invoice],
        operation: (Int, HarvestCredentials) async throws -> Void
    ) async {
        guard !invoices.isEmpty else { return }

        isUpdating = true
        updateError = nil
        updatedCount = 0

        do {
            let credentials = try await keychainService.loadHarvestCredentials()

            for invoice in invoices {
                try await operation(invoice.id, credentials)
                updatedCount += 1
            }

            showUpdateSuccess = true
            await performRefreshInvoices(ids: Set(invoices.map(\.id)))
        } catch {
            updateError = error.localizedDescription
        }

        isUpdating = false
    }

    func updateIssueDateForSelected(to date: Date) async {
        await performBatchOperation(on: selectedInvoices.filter { $0.state == .draft }) { id, credentials in
            try await self.apiService.updateInvoiceIssueDate(invoiceId: id, issueDate: date, credentials: credentials)
        }
    }

    func markAsSent(invoiceId: Int) async throws {
        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.markInvoiceAsSent(
            invoiceId: invoiceId,
            credentials: credentials
        )
    }

    func markSelectedAsSent() async {
        await performBatchOperation(on: selectedInvoices.filter { $0.state == .draft }) { id, credentials in
            try await self.apiService.markInvoiceAsSent(invoiceId: id, credentials: credentials)
        }
    }

    func markAsDraft(invoiceId: Int) async throws {
        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.markInvoiceAsDraft(
            invoiceId: invoiceId,
            credentials: credentials
        )
    }

    func markSelectedAsDraft() async {
        await performBatchOperation(on: selectedInvoices.filter { $0.state == .open }) { id, credentials in
            try await self.apiService.markInvoiceAsDraft(invoiceId: id, credentials: credentials)
        }
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

            // Load template if using template mode
            var template: InvoiceTemplate?
            if withQRBill && appSettings.effectivePDFSource == .template {
                guard let templateId = appSettings.selectedTemplateId,
                      let loaded = await loadTemplate(id: templateId) else {
                    exportError = "No template selected. Please select a template in Settings > Templates."
                    isExporting = false
                    return
                }
                template = loaded
            }

            for (index, invoice) in invoicesToExport.enumerated() {
                exportProgressMessage = "Exporting \(index + 1) of \(total): \(invoice.number)"
                exportProgress = Double(index) / Double(total)

                let document: PDFDocument
                if withQRBill {
                    if let template {
                        document = try await pdfService.createInvoiceFromTemplate(
                            invoice: invoice,
                            template: template,
                            creditorInfo: creditorInfo,
                            credentials: credentials,
                            language: appSettings.templateLanguage
                        )
                    } else {
                        document = try await pdfService.createInvoiceWithQRBill(
                            invoice: invoice,
                            credentials: credentials,
                            creditorInfo: creditorInfo
                        )
                    }
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
            Analytics.batchExportCompleted(count: exportedCount, withQRBill: withQRBill)
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    func loadTemplate(id: UUID) async -> InvoiceTemplate? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<InvoiceTemplate>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            logger.error("Failed to load template: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Drag & Drop
    // TODO: Drag-and-drop export is temporarily disabled (see InvoicesListView)

    func createDragProvider(for invoice: Invoice) -> NSItemProvider {
        let provider = NSItemProvider()

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

        provider.suggestedName = (fileName as NSString).deletingPathExtension

        let settings = appSettings
        let creditor = creditorInfo

        provider.registerFileRepresentation(for: .pdf, visibility: .all) { completion in
            Task { @MainActor [weak self] in
                guard let self else {
                    completion(nil, false, nil)
                    return
                }

                do {
                    let credentials = try await self.keychainService.loadHarvestCredentials()

                    let document: PDFDocument
                    if creditor.isValid {
                        if settings.effectivePDFSource == .template {
                            guard let templateId = settings.selectedTemplateId,
                                  let template = await self.loadTemplate(id: templateId) else {
                                throw NSError(domain: "HarvestQRBill", code: 1, userInfo: [
                                    NSLocalizedDescriptionKey: "No template selected. Please select a template in Settings > Templates."
                                ])
                            }
                            document = try await self.pdfService.createInvoiceFromTemplate(
                                invoice: invoice,
                                template: template,
                                creditorInfo: creditor,
                                credentials: credentials,
                                language: settings.templateLanguage
                            )
                        } else {
                            document = try await self.pdfService.createInvoiceWithQRBill(
                                invoice: invoice,
                                credentials: credentials,
                                creditorInfo: creditor
                            )
                        }
                    } else {
                        let pdfURL = try HarvestAPIService.shared.buildPDFURL(
                            for: invoice,
                            subdomain: credentials.subdomain
                        )
                        document = try await self.pdfService.downloadPDF(from: pdfURL)
                    }

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(fileName)
                    try await self.pdfService.savePDF(document, to: tempURL)
                    completion(tempURL, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }

            return Progress()
        }

        return provider
    }

}
