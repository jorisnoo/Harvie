import Foundation
import SwiftData
import Testing
@testable import Harvie

@Suite("Account caches")
@MainActor
struct DocumentCacheTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: CachedInvoice.self, CachedEstimate.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func invoiceCacheReconcilesOnlyFullFetchesForItsAccount() throws {
        let store = try container()
        let vm = InvoicesViewModel()
        vm.updateCache(with: [TestDocuments.invoice(id: 1), TestDocuments.invoice(id: 2)], context: store.mainContext, accountId: "a")
        vm.updateCache(with: [TestDocuments.invoice(id: 3)], context: store.mainContext, accountId: "b")
        vm.updateCache(with: [TestDocuments.invoice(id: 1)], context: store.mainContext, accountId: "a")
        vm.loadFromCache(context: store.mainContext, accountId: "a")
        #expect(Set(vm.invoices.map(\.id)) == [1, 2])
        vm.updateCache(with: [TestDocuments.invoice(id: 1)], context: store.mainContext, accountId: "a", replaceAll: true)
        vm.loadFromCache(context: store.mainContext, accountId: "a")
        #expect(vm.invoices.map(\.id) == [1])
        vm.loadFromCache(context: store.mainContext, accountId: "b")
        #expect(vm.invoices.map(\.id) == [3])
        vm.updateCache(with: [], context: store.mainContext, accountId: "b", replaceAll: true)
        vm.loadFromCache(context: store.mainContext, accountId: "b")
        #expect(vm.invoices.isEmpty)
    }

    @Test func estimateCacheReconcilesOnlyFullFetchesForItsAccount() throws {
        let store = try container()
        let vm = EstimatesViewModel()
        vm.updateCache(with: [TestDocuments.estimate(id: 1), TestDocuments.estimate(id: 2)], context: store.mainContext, accountId: "a")
        vm.updateCache(with: [TestDocuments.estimate(id: 3)], context: store.mainContext, accountId: "b")
        vm.updateCache(with: [TestDocuments.estimate(id: 1)], context: store.mainContext, accountId: "a")
        vm.loadFromCache(context: store.mainContext, accountId: "a")
        #expect(Set(vm.estimates.map(\.id)) == [1, 2])
        vm.updateCache(with: [TestDocuments.estimate(id: 1)], context: store.mainContext, accountId: "a", replaceAll: true)
        vm.loadFromCache(context: store.mainContext, accountId: "a")
        #expect(vm.estimates.map(\.id) == [1])
        vm.loadFromCache(context: store.mainContext, accountId: "b")
        #expect(vm.estimates.map(\.id) == [3])
    }

    @Test func failedRefreshPreservesOnlyCurrentAccountAndShowsError() async throws {
        try #require(AppEnvironment.isRunningTests)
        let store = try container()
        let keychain = KeychainService()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UnavailableAPIURLProtocol.self]
        let vm = InvoicesViewModel(apiService: HarvestAPIService(session: URLSession(configuration: config)), keychainService: keychain)
        vm.modelContext = store.mainContext
        vm.updateCache(with: [TestDocuments.invoice(id: 1)], context: store.mainContext, accountId: "a")
        vm.updateCache(with: [TestDocuments.invoice(id: 2)], context: store.mainContext, accountId: "b")
        // Legacy records have no verified owner and must never appear in either account.
        store.mainContext.insert(CachedInvoice(from: TestDocuments.invoice(id: 3)))
        try store.mainContext.save()
        for (account, expectedID) in [("a", 1), ("b", 2)] {
            try await keychain.saveHarvestCredentials(HarvestCredentials(accessToken: "fixture", accountId: account, subdomain: "fixture"))
            await vm.performLoadInvoices()
            #expect(vm.invoices.map(\.id) == [expectedID])
            #expect(vm.error != nil)
            #expect(vm.lastRefreshed != nil)
        }
        vm.selectedInvoiceIDs = [2]
        try await keychain.delete(for: .harvestCredentials)
        await vm.performLoadInvoices()
        #expect(vm.invoices.isEmpty)
        #expect(vm.selectedInvoiceIDs.isEmpty)
        #expect(!vm.hasValidCredentials)
    }

    @Test func settingsSavePreservesLatestListState() {
        var latest = AppSettings.default
        latest.lastSortOption = "Due Date"
        latest.lastSelectedStates = ["paid"]
        latest.lastSelectedEstimateStates = ["accepted"]
        var preferences = AppSettings.default
        preferences.filenamePattern = "{client}-{number}"
        let merged = AppSettingsStorage.mergingPreferences(preferences, into: latest)
        #expect(merged.lastSortOption == latest.lastSortOption)
        #expect(merged.lastSelectedStates == latest.lastSelectedStates)
        #expect(merged.lastSelectedEstimateStates == latest.lastSelectedEstimateStates)
        #expect(merged.filenamePattern == preferences.filenamePattern)
    }
}

private final class UnavailableAPIURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
