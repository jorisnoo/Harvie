//
//  InvoicesViewModel.swift
//  Harvie
//

import Foundation
import os.log
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "InvoicesVM")

@Observable
@MainActor
final class InvoicesViewModel: BatchUpdating {
    var invoices: [Invoice] = [] {
        didSet {
            invoicesById = Dictionary(invoices.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
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
    /// States to show. An empty set means "All" (no state filtering).
    var selectedStates: Set<InvoiceState> = [.open] {
        didSet {
            guard !isBatchUpdating, isInitialized else { return }
            if !validSortOptions.contains(sortOption) {
                sortOption = .issueDate
            }
            updateSortedInvoices()
            clearInvalidSelections()
            debouncedSaveState()
        }
    }
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
    private var activeAccountId: String?
    private(set) var lastRefreshed: Date?
    var hasValidCredentials = false
    @ObservationIgnored private(set) var isInitialized = false

    @ObservationIgnored private var isBatchUpdating = false
    @ObservationIgnored private var loadInvoicesTask: Task<Void, Never>?
    @ObservationIgnored private var saveStateTask: Task<Void, Never>?
    /// Invoices refreshed one by one since the last full load started; they win over
    /// older copies when a slow full load lands.
    @ObservationIgnored private var refreshedDuringLoad: [Int: Invoice] = [:]

    private(set) var availablePeriods: [Date] = DateFilterPeriod.month.periods()

    var validSortOptions: [InvoiceSortOption] {
        guard !selectedStates.isEmpty else { return InvoiceSortOption.allCases }

        let optionsFor: (InvoiceState) -> Set<InvoiceSortOption> = { state in
            switch state {
            case .draft: [.issueDate]
            case .open: [.issueDate, .dueDate]
            case .paid, .closed: Set(InvoiceSortOption.allCases)
            }
        }

        let allowed = selectedStates
            .map(optionsFor)
            .reduce(Set(InvoiceSortOption.allCases)) { $0.intersection($1) }

        return InvoiceSortOption.allCases.filter { allowed.contains($0) }
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
    var updateTotalCount = 0

    // Batch action sheet triggers (shared by MultiSelectionView and list context menu)
    var showChangeDateSheet = false
    var showMarkAsSentSheet = false
    var showMarkAsDraftSheet = false
    var showMarkAsPaidSheet = false
    var showMarkAsOpenSheet = false
    var showConfirmDateSheet = false
    var showDeleteSheet = false
    var showNewInvoiceSheet = false
    var batchIssueDate = Date()
    var batchPaymentDate = Date()

    var anySelectedHasNonTodayDate: Bool {
        selectedInvoices.contains { !Calendar.current.isDateInToday($0.issueDate) }
    }

    func initiateMarkAsSent() {
        if anySelectedHasNonTodayDate {
            showConfirmDateSheet = true
        } else {
            showMarkAsSentSheet = true
        }
    }

    func initiateChangeDate() {
        batchIssueDate = selectedInvoices.first?.issueDate ?? Date()
        showChangeDateSheet = true
    }

    func initiateMarkAsPaid() {
        batchPaymentDate = Date()
        showMarkAsPaidSheet = true
    }

    var allSelectedAreDrafts: Bool {
        guard !selectedInvoiceIDs.isEmpty else { return false }

        return selectedInvoices.allSatisfy { $0.state == .draft }
    }

    var allSelectedAreOpen: Bool {
        guard !selectedInvoiceIDs.isEmpty else { return false }

        return selectedInvoices.allSatisfy { $0.state == .open }
    }

    var allSelectedArePaid: Bool {
        guard !selectedInvoiceIDs.isEmpty else { return false }

        return selectedInvoices.allSatisfy { $0.state == .paid }
    }

    @ObservationIgnored var modelContext: ModelContext?

    private let apiService: HarvestAPIService
    private let keychainService: KeychainService

    init(apiService: HarvestAPIService = .shared, keychainService: KeychainService = .shared) {
        self.apiService = apiService
        self.keychainService = keychainService
    }
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

        if let savedStates = settings.lastSelectedStates {
            selectedStates = Set(savedStates.compactMap { InvoiceState(rawValue: $0) })
        } else if let stateFilterRaw = settings.lastStateFilter {
            // Migrate the legacy single-state filter ("" meant "All").
            selectedStates = InvoiceState(rawValue: stateFilterRaw).map { [$0] } ?? []
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
        // Merge into the latest persisted settings so another document view cannot
        // overwrite independently saved preferences with a stale in-memory copy.
        var settings = AppSettingsStorage.load()
        settings.lastSortOption = sortOption.rawValue
        settings.lastSortAscending = sortDirection == .ascending
        settings.lastFilterPeriod = filterPeriod.rawValue
        settings.lastSelectedPeriod = selectedPeriod
        settings.lastSelectedStates = selectedStates.map(\.rawValue)
        AppSettingsStorage.save(settings)
        appSettings = settings
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

        if !selectedStates.isEmpty {
            filtered = filtered.filter { selectedStates.contains($0.state) }
        }

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
                    dateToCheck = invoice.effectivePaidDate ?? invoice.issueDate
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
                lhsDate = lhs.effectivePaidDate ?? .distantPast
                rhsDate = rhs.effectivePaidDate ?? .distantPast
            }

            return sortDirection == .ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        }

        if newSorted != sortedInvoices {
            sortedInvoices = newSorted
        }
    }

    func loadInvoices() {
        loadInvoicesTask?.cancel()
        loadInvoicesTask = Task {
            await performLoadInvoices()
        }
    }

    func performLoadInvoices() async {
        error = nil

        #if DEBUG
        // Check for demo mode first
        if appSettings.isDemoMode {
            loadDemoInvoices()
            return
        }
        #endif

        do {
            try Task.checkCancellation()

            let credentials = try await keychainService.loadHarvestCredentials()
            try Task.checkCancellation()

            guard credentials.isValid else {
                signOut()
                isLoading = false
                isRefreshing = false
                return
            }

            activateAccount(credentials.accountId)
            isLoading = invoices.isEmpty
            isRefreshing = !invoices.isEmpty
            hasValidCredentials = true

            try Task.checkCancellation()

            refreshedDuringLoad = [:]
            let fetchedInvoices = try await apiService.fetchAllInvoices(credentials: credentials)

            try Task.checkCancellation()

            invoices = fetchedInvoices.uniquedByID().merging(Array(refreshedDuringLoad.values))
            refreshedDuringLoad = [:]
            lastRefreshed = Date()
            clearInvalidSelections()
            Analytics.invoicesLoaded(count: invoices.count)

            if let context = modelContext {
                updateCache(with: invoices, context: context, accountId: credentials.accountId, replaceAll: true)
            }
        } catch is CancellationError {
            return
        } catch KeychainService.KeychainError.notFound {
            guard !Task.isCancelled else { return }
            signOut()
        } catch {
            // URLSession surfaces task cancellation as URLError(.cancelled), not
            // CancellationError — a superseded load must not clobber its replacement's state.
            guard !Task.isCancelled else { return }

            if error is KeychainService.KeychainError { clearAccountData() }
            self.error = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    #if DEBUG
    private func loadDemoInvoices() {
        hasValidCredentials = true
        // Load all states; updateSortedInvoices applies the client-side state filter.
        invoices = DemoDataProvider.invoices
        isLoading = false
        isRefreshing = false
    }
    #endif

    func clearAccountData() {
        invoices = []
        selectedInvoiceIDs = []
        activeAccountId = nil
        lastRefreshed = nil
        hasValidCredentials = false
        refreshedDuringLoad = [:]
    }

    /// Credentials are missing or incomplete: forget every account's invoices, on disk too.
    private func signOut() {
        clearAccountData()
        purgeCache(keeping: nil)
        error = Strings.Errors.configureCredentials
    }

    /// Switches to `accountId`, dropping other accounts' invoices from memory and disk,
    /// and shows its cached invoices until the fetch completes.
    private func activateAccount(_ accountId: String) {
        if activeAccountId != accountId {
            clearAccountData()
            activeAccountId = accountId
            purgeCache(keeping: accountId)
        }
        if let context = modelContext {
            loadFromCache(context: context, accountId: accountId)
        }
    }

    func loadFromCache(context: ModelContext, accountId: String) {
        guard let cached = DocumentCache<CachedInvoice>(context: context).load(accountId: accountId) else { return }
        lastRefreshed = cached.lastFetched
        // Load all states; updateSortedInvoices applies the client-side state filter.
        invoices = cached.documents
    }

    func updateCache(with invoices: [Invoice], context: ModelContext, accountId: String, replaceAll: Bool = false) {
        DocumentCache<CachedInvoice>(context: context).store(invoices, accountId: accountId, replaceAll: replaceAll)
    }

    private func purgeCache(keeping accountId: String?) {
        guard let context = modelContext else { return }
        DocumentCache<CachedInvoice>(context: context).purge(keeping: accountId)
    }

    func refresh() {
        loadInvoices()
    }

    func refreshInvoices(ids: Set<Int>) {
        Task {
            await performRefreshInvoices(ids: ids)
        }
    }

    func switchFilterAndSelect(invoiceId: Int, to newState: InvoiceState) {
        // Make sure the invoice stays visible under the active filter, then keep it selected.
        // No refetch needed: filtering is client-side. Refresh just this invoice to pick up
        // its new state.
        if !selectedStates.isEmpty {
            selectedStates.insert(newState)
        }
        selectedInvoiceIDs = [invoiceId]
        refreshInvoices(ids: [invoiceId])
    }

    private func performRefreshInvoices(ids: Set<Int>) async {
        guard let credentials = try? await keychainService.loadHarvestCredentials(),
              credentials.accountId == activeAccountId else { return }

        let api = apiService
        let (fetched, failures) = await fetchEach(ids) { id in
            try await api.fetchInvoice(id: id, credentials: credentials)
        }
        for failure in failures {
            // The list keeps the invoice's previous copy.
            logger.warning("Failed to refresh invoice \(failure.id): \(failure.error.localizedDescription)")
        }

        guard credentials.accountId == activeAccountId else { return }
        for invoice in fetched {
            refreshedDuringLoad[invoice.id] = invoice
        }
        // Unknown IDs are added: they exist in this account, and are cached below either way.
        // updateSortedInvoices re-applies the client-side state filter.
        invoices = invoices.merging(fetched)

        if let context = modelContext {
            updateCache(with: fetched, context: context, accountId: credentials.accountId)
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

    func updateDates(for invoiceId: Int, issueDate: Date, dueDate: Date) async throws {
        #if DEBUG
        if appSettings.isDemoMode { return }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.updateInvoiceDates(
            invoiceId: invoiceId,
            issueDate: issueDate,
            dueDate: dueDate,
            credentials: credentials
        )
    }

    // MARK: - Batch Operations

    private func runBatch(
        on invoices: [Invoice],
        operation: (Int, HarvestCredentials) async throws -> Void
    ) async {
        await performBatchOperation(on: invoices.map(\.id), operation: operation) { ids in
            await performRefreshInvoices(ids: ids)
        }
    }

    func updateIssueDateForSelected(to date: Date) async {
        // Harvest accepts date changes on open invoices too; the due date keeps the
        // invoice's payment term, as in the detail view.
        let invoices = selectedInvoices.filter { $0.state == .draft || $0.state == .open }
        let paymentTerms = Dictionary(
            invoices.map { ($0.id, PaymentTerm.from(issueDate: $0.issueDate, dueDate: $0.dueDate)) },
            uniquingKeysWith: { first, _ in first }
        )
        await runBatch(on: invoices) { id, credentials in
            let dueDate = paymentTerms[id]?.dueDate(from: date) ?? date
            try await self.apiService.updateInvoiceDates(invoiceId: id, issueDate: date, dueDate: dueDate, credentials: credentials)
        }
    }

    func markAsSent(invoiceId: Int) async throws {
        #if DEBUG
        if appSettings.isDemoMode { return }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.markInvoiceAsSent(
            invoiceId: invoiceId,
            credentials: credentials
        )
    }

    func markSelectedAsSent() async {
        await runBatch(on: selectedInvoices.filter { $0.state == .draft }) { id, credentials in
            try await self.apiService.markInvoiceAsSent(invoiceId: id, credentials: credentials)
        }
    }

    func markAsDraft(invoiceId: Int) async throws {
        #if DEBUG
        if appSettings.isDemoMode { return }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        try await apiService.markInvoiceAsDraft(
            invoiceId: invoiceId,
            credentials: credentials
        )
    }

    func markSelectedAsDraft() async {
        await runBatch(on: selectedInvoices.filter { $0.state == .open }) { id, credentials in
            try await self.apiService.markInvoiceAsDraft(invoiceId: id, credentials: credentials)
        }
    }

    func markSelectedAsPaid(paidAt: Date = Date()) async {
        await runBatch(on: selectedInvoices.filter { $0.state == .open }) { id, credentials in
            try await self.apiService.payOutstandingBalance(invoiceId: id, paidAt: paidAt, credentials: credentials)
        }
    }

    func markAsOpen(invoiceId: Int) async throws {
        #if DEBUG
        if appSettings.isDemoMode { return }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        try await deletePayments(invoiceId: invoiceId, credentials: credentials)
    }

    func markSelectedAsOpen() async {
        await runBatch(on: selectedInvoices.filter { $0.state == .paid }) { id, credentials in
            try await self.deletePayments(invoiceId: id, credentials: credentials)
        }
    }

    private func deletePayments(invoiceId: Int, credentials: HarvestCredentials) async throws {
        let payments = try await apiService.listPayments(invoiceId: invoiceId, credentials: credentials)
        for payment in payments {
            try await apiService.deletePayment(invoiceId: invoiceId, paymentId: payment.id, credentials: credentials)
        }
    }

    // MARK: - Create & Delete

    /// Active clients and line item kinds offered when creating an invoice.
    func loadNewInvoiceOptions() async throws -> (clients: [Client], kinds: [String]) {
        #if DEBUG
        if appSettings.isDemoMode {
            let clients = Dictionary(grouping: invoices, by: \.client.id).values.compactMap(\.first).map {
                Client(id: $0.client.id, name: $0.client.name, currency: $0.currency)
            }
            return (clients.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, ["Service", "Product"])
        }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        async let clients = apiService.fetchActiveClients(credentials: credentials)
        async let categories = apiService.fetchInvoiceItemCategories(credentials: credentials)
        return (
            try await clients.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            try await categories.map(\.name)
        )
    }

    /// Creates the invoice in Harvest, then shows and selects it in the list.
    func createInvoice(_ newInvoice: NewInvoice) async throws {
        #if DEBUG
        if appSettings.isDemoMode {
            insertCreatedInvoice(Self.demoInvoice(from: newInvoice, existing: invoices))
            return
        }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        let invoice = try await apiService.createInvoice(newInvoice, credentials: credentials)
        guard credentials.accountId == activeAccountId else { return }

        insertCreatedInvoice(invoice)
        if let context = modelContext {
            updateCache(with: [invoice], context: context, accountId: credentials.accountId)
        }
    }

    private func insertCreatedInvoice(_ invoice: Invoice) {
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        } else {
            invoices.append(invoice)
        }
        if !selectedStates.isEmpty {
            selectedStates.insert(invoice.state)
        }
        if !sortedInvoices.contains(where: { $0.id == invoice.id }) {
            selectedPeriod = nil
            searchText = ""
        }
        selectedInvoiceIDs = [invoice.id]
    }

    /// Deletes the selected invoices from Harvest. Returns `true` when all were deleted.
    func deleteSelectedInvoices() async -> Bool {
        let ids = selectedInvoiceIDs
        guard !ids.isEmpty, !isUpdating else { return false }

        #if DEBUG
        if appSettings.isDemoMode {
            removeInvoices(ids: ids)
            return true
        }
        #endif

        isUpdating = true
        updateError = nil
        updatedCount = 0
        updateTotalCount = ids.count

        var deleted: Set<Int> = []
        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            for id in ids {
                try await apiService.deleteInvoice(id: id, credentials: credentials)
                deleted.insert(id)
                updatedCount += 1
            }
        } catch {
            updateError = error.localizedDescription
        }

        removeInvoices(ids: deleted)
        isUpdating = false
        return updateError == nil
    }

    private func removeInvoices(ids: Set<Int>) {
        guard !ids.isEmpty else { return }
        invoices.removeAll { ids.contains($0.id) }
        selectedInvoiceIDs.subtract(ids)

        guard let context = modelContext else { return }
        let idList = Array(ids)
        do {
            try context.delete(model: CachedInvoice.self, where: #Predicate { idList.contains($0.id) })
            try context.save()
        } catch {
            logger.warning("Failed to remove deleted invoices from cache: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    private static func demoInvoice(from newInvoice: NewInvoice, existing: [Invoice]) -> Invoice {
        let id = Int.random(in: 100_000...999_999)
        let sameClient = existing.first { $0.client.id == newInvoice.clientId }
        let amount = newInvoice.lineItems.reduce(Decimal.zero) { $0 + $1.quantity * $1.unitPrice }
        let tax = amount * (newInvoice.taxRate ?? 0) / 100
        return Invoice(
            id: id,
            clientKey: "demo-\(id)",
            number: "INV-\(id)",
            amount: amount + tax,
            dueAmount: amount + tax,
            tax: newInvoice.taxRate,
            taxAmount: newInvoice.taxRate.map { _ in tax },
            subject: newInvoice.subject,
            notes: newInvoice.notes,
            currency: sameClient?.currency ?? "CHF",
            state: .draft,
            issueDate: newInvoice.issueDate,
            dueDate: newInvoice.dueDate,
            createdAt: Date(),
            updatedAt: Date(),
            client: sameClient?.client ?? ClientReference(id: newInvoice.clientId, name: "Demo Client"),
            lineItems: newInvoice.lineItems.enumerated().map { index, item in
                LineItem(
                    id: id * 100 + index,
                    kind: item.kind,
                    description: item.description,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    amount: item.quantity * item.unitPrice,
                    taxed: newInvoice.taxRate != nil,
                    taxed2: false,
                    project: nil
                )
            }
        )
    }
    #endif
}
