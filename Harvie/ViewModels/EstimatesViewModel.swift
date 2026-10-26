//
//  EstimatesViewModel.swift
//  Harvie
//

import Foundation
import os.log
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "EstimatesVM")

@Observable
@MainActor
final class EstimatesViewModel: BatchUpdating {
    var estimates: [Estimate] = [] {
        didSet {
            estimatesById = Dictionary(estimates.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            updateSortedEstimates()
            updateSelectedEstimate()
        }
    }
    var selectedEstimateIDs: Set<Int> = [] {
        didSet { updateSelectedEstimate() }
    }

    private(set) var selectedEstimate: Estimate?
    var isLoading = false
    var isRefreshing = false
    var error: String?
    /// States to show. An empty set means "All" (no state filtering).
    var selectedStates: Set<EstimateState> = [.sent] {
        didSet {
            guard !isBatchUpdating, isInitialized else { return }
            updateSortedEstimates()
            clearInvalidSelections()
            debouncedSaveState()
        }
    }
    var sortDirection: SortDirection = .descending {
        didSet { if !isBatchUpdating { updateSortedEstimates() } }
    }
    var searchText = "" {
        didSet { if !isBatchUpdating { updateSortedEstimates() } }
    }
    private var activeAccountId: String?
    private(set) var lastRefreshed: Date?
    var hasValidCredentials = false
    @ObservationIgnored private(set) var isInitialized = false

    @ObservationIgnored private var isBatchUpdating = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var saveStateTask: Task<Void, Never>?
    /// Estimates refreshed one by one since the last full load started; they win over
    /// older copies when a slow full load lands.
    @ObservationIgnored private var refreshedDuringLoad: [Int: Estimate] = [:]

    var creditorInfo: CreditorInfo = .empty
    var appSettings: AppSettings = .default
    @ObservationIgnored private(set) var estimatesById: [Int: Estimate] = [:]

    // Batch export state
    var isExporting = false
    var exportProgress: Double = 0
    var exportProgressMessage: String = ""
    var exportError: String?
    var showExportSuccess = false
    var exportedCount = 0

    // State-transition state
    var isUpdating = false
    var updateError: String?
    var showUpdateSuccess = false
    var updatedCount = 0
    var updateTotalCount = 0

    var selectedEstimates: [Estimate] {
        selectedEstimateIDs.compactMap { estimatesById[$0] }
    }

    var allSelectedAreDrafts: Bool {
        guard !selectedEstimateIDs.isEmpty else { return false }
        return selectedEstimates.allSatisfy { $0.state == .draft }
    }

    var allSelectedAreSent: Bool {
        guard !selectedEstimateIDs.isEmpty else { return false }
        return selectedEstimates.allSatisfy { $0.state == .sent }
    }

    var allSelectedAreFinalized: Bool {
        guard !selectedEstimateIDs.isEmpty else { return false }
        return selectedEstimates.allSatisfy { $0.state == .accepted || $0.state == .declined }
    }

    @ObservationIgnored var modelContext: ModelContext?

    private let apiService: HarvestAPIService
    private let keychainService: KeychainService

    init(apiService: HarvestAPIService = .shared, keychainService: KeychainService = .shared) {
        self.apiService = apiService
        self.keychainService = keychainService
    }

    private(set) var sortedEstimates: [Estimate] = []

    // MARK: - Lifecycle

    func loadSavedState() async {
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }
        appSettings = AppSettingsStorage.load()

        isBatchUpdating = true
        if let savedStates = appSettings.lastSelectedEstimateStates {
            selectedStates = Set(savedStates.compactMap { EstimateState(rawValue: $0) })
        }
        isBatchUpdating = false

        isInitialized = true
        updateSortedEstimates()
    }

    func reloadSettings() async {
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }
        appSettings = AppSettingsStorage.load()
    }

    private func debouncedSaveState() {
        saveStateTask?.cancel()
        saveStateTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            var settings = AppSettingsStorage.load()
            settings.lastSelectedEstimateStates = selectedStates.map(\.rawValue)
            AppSettingsStorage.save(settings)
            appSettings = settings
        }
    }

    // MARK: - Sorting & Filtering

    private func updateSelectedEstimate() {
        let newValue: Estimate?
        if selectedEstimateIDs.count == 1, let id = selectedEstimateIDs.first {
            newValue = estimatesById[id]
        } else {
            newValue = nil
        }
        if selectedEstimate != newValue {
            selectedEstimate = newValue
        }
    }

    private func updateSortedEstimates() {
        var filtered = estimates

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

        let newSorted = filtered.sorted { lhs, rhs in
            sortDirection == .ascending ? lhs.issueDate < rhs.issueDate : lhs.issueDate > rhs.issueDate
        }

        if newSorted != sortedEstimates {
            sortedEstimates = newSorted
        }
    }

    // MARK: - Loading

    func loadEstimates() {
        loadTask?.cancel()
        loadTask = Task {
            await performLoad()
        }
    }

    func refresh() { loadEstimates() }

    func performLoad() async {
        error = nil

        #if DEBUG
        if appSettings.isDemoMode {
            hasValidCredentials = true
            estimates = []
            isLoading = false
            isRefreshing = false
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
            isLoading = estimates.isEmpty
            isRefreshing = !estimates.isEmpty
            hasValidCredentials = true
            try Task.checkCancellation()

            refreshedDuringLoad = [:]
            let fetched = try await apiService.fetchAllEstimates(
                credentials: credentials,
                state: nil
            )

            try Task.checkCancellation()

            estimates = fetched.uniquedByID().merging(Array(refreshedDuringLoad.values))
            refreshedDuringLoad = [:]
            lastRefreshed = Date()
            clearInvalidSelections()
            Analytics.estimatesLoaded(count: estimates.count)

            if let context = modelContext {
                updateCache(with: estimates, context: context, accountId: credentials.accountId, replaceAll: true)
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

    func clearAccountData() {
        estimates = []
        selectedEstimateIDs = []
        activeAccountId = nil
        lastRefreshed = nil
        hasValidCredentials = false
        refreshedDuringLoad = [:]
    }

    /// Credentials are missing or incomplete: forget every account's estimates, on disk too.
    private func signOut() {
        clearAccountData()
        purgeCache(keeping: nil)
        error = Strings.Errors.configureCredentials
    }

    /// Switches to `accountId`, dropping other accounts' estimates from memory and disk,
    /// and shows its cached estimates until the fetch completes.
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
        guard let cached = DocumentCache<CachedEstimate>(context: context).load(accountId: accountId) else { return }
        lastRefreshed = cached.lastFetched
        estimates = cached.documents
    }

    func updateCache(with estimates: [Estimate], context: ModelContext, accountId: String, replaceAll: Bool = false) {
        DocumentCache<CachedEstimate>(context: context).store(estimates, accountId: accountId, replaceAll: replaceAll)
    }

    private func purgeCache(keeping accountId: String?) {
        guard let context = modelContext else { return }
        DocumentCache<CachedEstimate>(context: context).purge(keeping: accountId)
    }

    // MARK: - Refresh subset

    func refreshEstimates(ids: Set<Int>) {
        Task { await performRefresh(ids: ids) }
    }

    func switchFilterAndSelect(estimateId: Int, to newState: EstimateState) {
        // Keep the transitioned estimate visible when a state filter is active.
        if !selectedStates.isEmpty {
            selectedStates.insert(newState)
        }
        selectedEstimateIDs = [estimateId]
        refreshEstimates(ids: [estimateId])
    }

    private func performRefresh(ids: Set<Int>) async {
        guard let credentials = try? await keychainService.loadHarvestCredentials(),
              credentials.accountId == activeAccountId else { return }

        let api = apiService
        let (fetched, failures) = await fetchEach(ids) { id in
            try await api.fetchEstimate(id: id, credentials: credentials)
        }
        for failure in failures {
            // The list keeps the estimate's previous copy.
            logger.warning("Failed to refresh estimate \(failure.id): \(failure.error.localizedDescription)")
        }

        guard credentials.accountId == activeAccountId else { return }
        for estimate in fetched {
            refreshedDuringLoad[estimate.id] = estimate
        }
        estimates = estimates.merging(fetched)

        if let context = modelContext {
            updateCache(with: fetched, context: context, accountId: credentials.accountId)
        }
    }

    // MARK: - Credentials

    func getCredentials() async throws -> HarvestCredentials {
        try await keychainService.loadHarvestCredentials()
    }

    func getCreditorInfo() async throws -> CreditorInfo {
        try await keychainService.loadCreditorInfo()
    }

    // MARK: - Selection

    func selectAll() {
        selectedEstimateIDs = Set(sortedEstimates.map(\.id))
    }

    func deselectAll() {
        selectedEstimateIDs.removeAll()
    }

    func clearInvalidSelections() {
        let visibleIDs = Set(sortedEstimates.map(\.id))
        let invalid = selectedEstimateIDs.subtracting(visibleIDs)
        if !invalid.isEmpty {
            selectedEstimateIDs.subtract(invalid)
        }
    }

    // MARK: - State transitions

    private func runBatch(
        on estimates: [Estimate],
        operation: (Int, HarvestCredentials) async throws -> Void
    ) async {
        await performBatchOperation(on: estimates.map(\.id), operation: operation) { ids in
            await performRefresh(ids: ids)
        }
    }

    func markSelectedAsSent() async {
        await runBatch(on: selectedEstimates.filter { $0.state == .draft }) { id, credentials in
            try await self.apiService.markEstimateAsSent(estimateId: id, credentials: credentials)
        }
    }

    func markSelectedAsAccepted() async {
        await runBatch(on: selectedEstimates.filter { $0.state == .sent }) { id, credentials in
            try await self.apiService.markEstimateAsAccepted(estimateId: id, credentials: credentials)
        }
    }

    func markSelectedAsDeclined() async {
        await runBatch(on: selectedEstimates.filter { $0.state == .sent }) { id, credentials in
            try await self.apiService.markEstimateAsDeclined(estimateId: id, credentials: credentials)
        }
    }

    func reopenSelected() async {
        let targets = selectedEstimates.filter { $0.state == .accepted || $0.state == .declined }
        await runBatch(on: targets) { id, credentials in
            try await self.apiService.reopenEstimate(estimateId: id, credentials: credentials)
        }
    }
}
