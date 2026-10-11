import Foundation
import Testing
@testable import Harvie

@Suite("Harvest export skips vanished parents")
@MainActor
struct HarvestExporterSkipTests {
    @Test("A parent deleted mid-export is skipped and reported, other records are kept")
    func skipsMissingParent() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let exporter = HarvestExporter(client: HarvestRawAPIClient(session: HarvestAPIStub.session()))
        let summary = try await exporter.runExport(
            to: folder, selectedResources: [.invoicePayments],
            credentials: HarvestAPIStub.credentials("exportSkip"),
            progress: { _ in }
        )

        let result = try #require(summary.results.first)
        #expect(result.recordCount == 1)
        #expect(result.errorMessage?.contains("IDs: 2") == true)
        let data = try Data(contentsOf: folder.appendingPathComponent("invoice_payments.json"))
        let rows = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(rows.map { $0["invoice_id"] as? Int } == [1])
    }
}
