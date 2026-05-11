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
final class EstimatesViewModel {
    var estimates: [Estimate] = [] {
        didSet {
            estimatesById = Dictionary(uniqueKeysWithValues: estimates.map { ($0.id, $0) })
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
    var stateFilter: EstimateState? = .sent
    var sortDirection: SortDirection = .descending {
        didSet { if !isBatchUpdating { updateSortedEstimates() } }
    }
    var searchText = "" {
        didSet { if !isBatchUpdating { updateSortedEstimates() } }
    }
    var hasValidCredentials = false
    @ObservationIgnored private(set) var isInitialized = false

    @ObservationIgnored private var isBatchUpdating = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?

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

    private let apiService = HarvestAPIService.shared
    private let keychainService = KeychainService.shared

    private(set) var sortedEstimates: [Estimate] = []

    // MARK: - Lifecycle

    func loadSavedState() async {
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }
        appSettings = AppSettingsStorage.load()
        isInitialized = true
        updateSortedEstimates()
    }

    func reloadSettings() async {
        if let loadedCreditorInfo = try? await keychainService.loadCreditorInfo() {
            creditorInfo = loadedCreditorInfo
        }
        appSettings = AppSettingsStorage.load()
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

    private func performLoad() async {
        error = nil
        let currentStateFilter = stateFilter

        #if DEBUG
        if appSettings.isDemoMode {
            hasValidCredentials = true
            estimates = []
            isLoading = false
            isRefreshing = false
            return
        }
        #endif

        if let context = modelContext {
            loadFromCache(context: context)
        }

        if estimates.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }

        do {
            try Task.checkCancellation()
            let credentials = try await keychainService.loadHarvestCredentials()

            guard credentials.isValid else {
                hasValidCredentials = false
                error = Strings.Errors.configureCredentials
                isLoading = false
                isRefreshing = false
                return
            }

            hasValidCredentials = true
            try Task.checkCancellation()

            let fetched = try await apiService.fetchAllEstimates(
                credentials: credentials,
                state: currentStateFilter
            )

            try Task.checkCancellation()
            guard stateFilter == currentStateFilter else { return }

            estimates = fetched
            Analytics.estimatesLoaded(count: fetched.count)

            if let context = modelContext {
                updateCache(with: fetched, context: context)
            }
        } catch is CancellationError {
            return
        } catch KeychainService.KeychainError.notFound {
            hasValidCredentials = false
            error = Strings.Errors.configureCredentials
        } catch {
            if estimates.isEmpty {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
        isRefreshing = false
    }

    private func loadFromCache(context: ModelContext) {
        let descriptor = FetchDescriptor<CachedEstimate>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )

        do {
            let cached = try context.fetch(descriptor)
            let filtered: [CachedEstimate]
            if let stateFilter {
                filtered = cached.filter { $0.stateRaw == stateFilter.rawValue }
            } else {
                filtered = cached
            }
            estimates = filtered.map { $0.toEstimate() }
        } catch {
            logger.warning("Failed to load estimate cache: \(error.localizedDescription)")
        }
    }

    private func updateCache(with estimates: [Estimate], context: ModelContext) {
        let descriptor = FetchDescriptor<CachedEstimate>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for estimate in estimates {
            if let cached = existingById[estimate.id] {
                cached.update(from: estimate)
            } else {
                let cached = CachedEstimate(from: estimate)
                context.insert(cached)
            }
        }

        do {
            try context.save()
        } catch {
            logger.warning("Failed to save estimate cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Refresh subset

    func refreshEstimates(ids: Set<Int>) {
        Task { await performRefresh(ids: ids) }
    }

    func switchFilterAndSelect(estimateId: Int, to newState: EstimateState) {
        if let current = stateFilter, current != newState {
            stateFilter = newState
        }
        loadTask?.cancel()
        loadTask = Task {
            await performLoad()
            selectedEstimateIDs = [estimateId]
        }
    }

    func refreshCurrentFilter() {
        selectedEstimateIDs = []
        loadTask?.cancel()
        loadTask = Task { await performLoad() }
    }

    private func performRefresh(ids: Set<Int>) async {
        guard let credentials = try? await keychainService.loadHarvestCredentials() else { return }

        var fetched: [Estimate] = []
        await withTaskGroup(of: Estimate?.self) { group in
            for id in ids {
                group.addTask {
                    try? await self.apiService.fetchEstimate(id: id, credentials: credentials)
                }
            }
            for await estimate in group {
                if let estimate { fetched.append(estimate) }
            }
        }

        var updated = estimates
        for estimate in fetched {
            if let index = updated.firstIndex(where: { $0.id == estimate.id }) {
                if let stateFilter, estimate.state != stateFilter {
                    updated.remove(at: index)
                } else {
                    updated[index] = estimate
                }
            }
        }
        estimates = updated

        let currentIDs = Set(updated.map(\.id))
        selectedEstimateIDs = selectedEstimateIDs.intersection(currentIDs)

        if let context = modelContext {
            updateCache(with: fetched, context: context)
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

    private func performBatchOperation(
        on estimates: [Estimate],
        operation: (Int, HarvestCredentials) async throws -> Void
    ) async {
        guard !estimates.isEmpty else { return }

        #if DEBUG
        if appSettings.isDemoMode {
            showUpdateSuccess = true
            return
        }
        #endif

        isUpdating = true
        updateError = nil
        updatedCount = 0
        updateTotalCount = estimates.count

        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            for estimate in estimates {
                try await operation(estimate.id, credentials)
                updatedCount += 1
            }
            showUpdateSuccess = true
            await performRefresh(ids: Set(estimates.map(\.id)))
        } catch {
            updateError = error.localizedDescription
        }

        isUpdating = false
    }

    func markSelectedAsSent() async {
        await performBatchOperation(on: selectedEstimates.filter { $0.state == .draft }) { id, credentials in
            try await self.apiService.markEstimateAsSent(estimateId: id, credentials: credentials)
        }
    }

    func markSelectedAsAccepted() async {
        await performBatchOperation(on: selectedEstimates.filter { $0.state == .sent }) { id, credentials in
            try await self.apiService.markEstimateAsAccepted(estimateId: id, credentials: credentials)
        }
    }

    func markSelectedAsDeclined() async {
        await performBatchOperation(on: selectedEstimates.filter { $0.state == .sent }) { id, credentials in
            try await self.apiService.markEstimateAsDeclined(estimateId: id, credentials: credentials)
        }
    }

    func reopenSelected() async {
        let targets = selectedEstimates.filter { $0.state == .accepted || $0.state == .declined }
        await performBatchOperation(on: targets) { id, credentials in
            try await self.apiService.reopenEstimate(estimateId: id, credentials: credentials)
        }
    }
}
