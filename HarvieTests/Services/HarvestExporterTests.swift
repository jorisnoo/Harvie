import Foundation
import Testing
@testable import Harvie

@Suite("Harvest exports")
struct HarvestExporterTests {
    @Test("Child-only exports fetch parents and use the API response keys", arguments: [
        HarvestExporter.Resource.invoicePayments, .invoiceMessages, .estimateMessages,
        .projectUserAssignments, .projectTaskAssignments, .userBillableRates,
        .userCostRates, .userProjectAssignments
    ])
    @MainActor
    func childOnly(resource: HarvestExporter.Resource) async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ExportURLProtocol.self]
        let client = HarvestRawAPIClient(session: URLSession(configuration: config))
        let summary = try await HarvestExporter(client: client).runExport(
            to: folder, selectedResources: [resource],
            credentials: HarvestCredentials(accessToken: "fixture", accountId: "fixture", subdomain: "fixture"),
            progress: { _ in }
        )
        #expect(!summary.hasFailures)
        #expect(summary.totalRecords == 1)
        let data = try Data(contentsOf: folder.appendingPathComponent("\(resource.rawValue).json"))
        let rows = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(rows.count == 1)
        #expect(rows.first?["id"] as? Int == 7)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(resource.parent!.rawValue).json").path))
    }

    @Test("Unexpected response shapes are reported as failures")
    @MainActor
    func unexpectedShape() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ExportURLProtocol.self]
        let exporter = HarvestExporter(client: HarvestRawAPIClient(session: URLSession(configuration: config)))
        let summary = try await exporter.runExport(
            to: folder, selectedResources: [.userBillableRates],
            credentials: HarvestCredentials(accessToken: "fixture", accountId: "malformed", subdomain: "fixture"),
            progress: { _ in }
        )
        #expect(summary.hasFailures)
        #expect(summary.successfulResources == 0)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("user_billable_rates.json").path))
    }
}

private final class ExportURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let component = request.url!.lastPathComponent
        let keys = ["payments": "invoice_payments", "messages": request.url!.path.contains("estimates") ? "estimate_messages" : "invoice_messages"]
        let key = keys[component] ?? component
        let malformed = request.value(forHTTPHeaderField: "Harvest-Account-Id") == "malformed" && component == "billable_rates"
        let body: [String: Any] = [malformed ? "unexpected" : key: [["id": 7]], "next_page": NSNull()]
        let data = try! JSONSerialization.data(withJSONObject: body)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
