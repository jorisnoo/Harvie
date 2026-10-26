import Foundation
import Testing
@testable import Harvie

@Suite("Settings saving")
@MainActor
struct SettingsViewModelTests {
    private func makeViewModel(_ keychain: KeychainService) -> SettingsViewModel {
        SettingsViewModel(keychainService: keychain, apiService: HarvestAPIService(session: HarvestAPIStub.session()))
    }

    @Test("A new token or account never keeps the previous account's subdomain")
    func changedAccountResolvesSubdomain() async throws {
        try #require(AppEnvironment.isRunningTests)
        let keychain = KeychainService()
        let vm = makeViewModel(keychain)
        var credentials = HarvestAPIStub.credentials("company")
        credentials.subdomain = "previous-account"
        vm.harvestCredentials = credentials

        await vm.saveSettings()
        #expect(vm.harvestCredentials.subdomain == "fresh")
        #expect(try await keychain.loadHarvestCredentials().subdomain == "fresh")

        // Editing anything else keeps the resolved subdomain without another lookup.
        vm.creditorInfo.name = "Changed"
        await vm.saveSettings()
        #expect(HarvestAPIStub.requests(for: credentials).count == 1)
        #expect(try await keychain.loadHarvestCredentials().subdomain == "fresh")

        // A failed lookup leaves the subdomain empty, which the app treats as incomplete credentials.
        vm.harvestCredentials.accountId = HarvestAPIStub.credentials("unauthorized").accountId
        await vm.saveSettings()
        let saved = try await keychain.loadHarvestCredentials()
        #expect(saved.subdomain.isEmpty)
        #expect(!saved.isValid)
    }

    @Test("Legacy keychain settings fill in untouched preferences and keep list state")
    func restoresLegacySettings() {
        var legacy = AppSettings.default
        legacy.filenamePattern = "{client}-{number}"

        #expect(AppSettingsStorage.restoring(legacy, over: nil) == legacy)

        var untouched = AppSettings.default
        untouched.lastSortOption = "Due Date"
        let restored = AppSettingsStorage.restoring(legacy, over: untouched)
        #expect(restored?.filenamePattern == legacy.filenamePattern)
        #expect(restored?.lastSortOption == "Due Date")

        var customized = AppSettings.default
        customized.dateFormat = "YYYY-MM-DD"
        #expect(AppSettingsStorage.restoring(legacy, over: customized) == nil)
    }
}
