import Foundation
import SwiftData
import Testing
@testable import Harvie

@Suite("Document list support")
@MainActor
struct DocumentListSupportTests {
    @Test func duplicateIDsDoNotCrashTheList() {
        let vm = InvoicesViewModel()
        vm.invoices = [TestDocuments.invoice(id: 1, number: "A"), TestDocuments.invoice(id: 1, number: "B")]
        #expect(vm.invoicesById[1]?.number == "B")
    }

    @Test func uniquedByIDKeepsLastCopyInFirstPosition() {
        let documents = [
            TestDocuments.invoice(id: 1, number: "old"),
            TestDocuments.invoice(id: 2),
            TestDocuments.invoice(id: 1, number: "new"),
        ].uniquedByID()
        #expect(documents.map(\.id) == [1, 2])
        #expect(documents.first?.number == "new")
    }

    @Test func mergingKeepsNewerCopiesAndAddsUnknownDocuments() {
        let current = [Self.invoice(1, updatedAt: 10, state: .open), Self.invoice(2, updatedAt: 10, state: .open)]
        let merged = current.merging([
            Self.invoice(1, updatedAt: 20, state: .paid),
            Self.invoice(2, updatedAt: 5, state: .draft),
            Self.invoice(3, updatedAt: 1, state: .open),
        ])
        #expect(merged.map(\.id) == [1, 2, 3])
        #expect(merged.map(\.state) == [.paid, .open, .open])
    }

    @Test func fetchEachBoundsConcurrencyAndReportsFailures() async {
        let gauge = ConcurrencyGauge()
        let result = await fetchEach(Set(1...10), maxConcurrent: 3) { (id: Int) async throws -> Int in
            await gauge.enter()
            try? await Task.sleep(for: .milliseconds(10))
            await gauge.leave()
            if id.isMultiple(of: 5) { throw URLError(.badServerResponse) }
            return id
        }
        #expect(Set(result.documents) == Set(1...10).subtracting([5, 10]))
        #expect(Set(result.failures.map { $0.id }) == [5, 10])
        #expect(await gauge.peak <= 3)
    }

    @Test func failedBatchRefreshesEveryAttemptedDocument() async {
        let probe = BatchProbe()
        var refreshed: Set<Int> = []
        await probe.performBatchOperation(on: [1, 2, 3]) { id, _ in
            if id == 2 { throw URLError(.badServerResponse) }
        } refresh: { ids in
            refreshed = ids
        }
        #expect(refreshed == [1, 2])
        #expect(probe.updatedCount == 1)
        #expect(probe.updateError != nil)
        #expect(!probe.showUpdateSuccess)
        #expect(!probe.isUpdating)
    }

    @Test func emptyBatchCompletesSoItsSheetCloses() async {
        let vm = InvoicesViewModel()
        await vm.updateIssueDateForSelected(to: Date())
        #expect(vm.showUpdateSuccess)
        #expect(vm.updateTotalCount == 0)
    }

    @Test func changeDateIncludesOpenInvoices() async throws {
        try #require(AppEnvironment.isRunningTests)
        // No stored credentials, so the batch stops before reaching the API.
        let vm = InvoicesViewModel(keychainService: KeychainService())
        vm.invoices = [
            TestDocuments.invoice(id: 1, state: .draft),
            TestDocuments.invoice(id: 2, state: .open),
            TestDocuments.invoice(id: 3, state: .paid),
        ]
        vm.selectedInvoiceIDs = [1, 2, 3]
        await vm.updateIssueDateForSelected(to: Date())
        #expect(vm.updateTotalCount == 2)
        #expect(vm.updateError != nil)
        #expect(!vm.isUpdating)
    }

    @Test func templateResolverFallsBackAndAppliesClientOverrides() throws {
        let store = try ModelContainer(for: InvoiceTemplate.self, ClientOverride.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = store.mainContext
        let beta = InvoiceTemplate(name: "Beta", htmlContent: "")
        let alpha = InvoiceTemplate(name: "Alpha", htmlContent: "")
        let clientOverride = ClientOverride(clientId: 7, clientName: "Fixture")
        clientOverride.templateLanguage = .de
        context.insert(beta)
        context.insert(alpha)
        context.insert(clientOverride)
        try context.save()

        let resolver = TemplateResolver(context: context)
        var settings = AppSettings.default
        settings.selectedTemplateId = beta.id
        #expect(resolver.template(for: settings)?.id == beta.id)
        settings.selectedTemplateId = UUID()
        #expect(resolver.template(for: settings)?.id == alpha.id)
        #expect(resolver.settings(settings, forClient: 7).templateLanguage == .de)
        #expect(resolver.settings(settings, forClient: 8).templateLanguage == settings.templateLanguage)
    }

    private static func invoice(_ id: Int, updatedAt: TimeInterval, state: InvoiceState) -> Invoice {
        let date = Date(timeIntervalSince1970: 1_788_220_800)
        return Invoice(id: id, clientKey: "fixture", number: "INV-\(id)", amount: 100, dueAmount: 100,
                       currency: "CHF", state: state, issueDate: date, dueDate: date, createdAt: date,
                       updatedAt: Date(timeIntervalSince1970: updatedAt), client: ClientReference(id: 1, name: "Fixture"))
    }
}

private actor ConcurrencyGauge {
    private var current = 0
    private(set) var peak = 0

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave() {
        current -= 1
    }
}

@MainActor
private final class BatchProbe: BatchUpdating {
    var isUpdating = false
    var updateError: String?
    var showUpdateSuccess = false
    var updatedCount = 0
    var updateTotalCount = 0
    var appSettings = AppSettings.default

    func getCredentials() async throws -> HarvestCredentials {
        HarvestCredentials(accessToken: "fixture", accountId: "fixture", subdomain: "fixture")
    }
}
