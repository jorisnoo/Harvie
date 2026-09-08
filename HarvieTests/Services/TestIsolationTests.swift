import Testing
@testable import Harvie

@Suite("Test isolation")
struct TestIsolationTests {
    @Test func testHostUsesMemoryOnlyKeychain() async throws {
        try #require(AppEnvironment.isRunningTests)
        let keychain = KeychainService()
        let value = HarvestCredentials(accessToken: "test-only", accountId: "fixture", subdomain: "fixture")
        try await keychain.saveHarvestCredentials(value)
        #expect(try await keychain.loadHarvestCredentials() == value)
        try await keychain.delete(for: .harvestCredentials)
        do {
            _ = try await keychain.loadHarvestCredentials()
            Issue.record("Expected no credentials in the isolated store")
        } catch KeychainService.KeychainError.notFound { }
    }
}
