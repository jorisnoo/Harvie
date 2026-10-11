import Foundation
@testable import Harvie

/// Serves canned Harvest responses. Each test uses credentials whose account ID is
/// `<scenario>:<uuid>`, so tests running in parallel never share request logs.
final class HarvestAPIStub: URLProtocol, @unchecked Sendable {
    static let recorder = HarvestAPIStubRecorder()

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HarvestAPIStub.self]
        return URLSession(configuration: config)
    }

    static func credentials(_ scenario: String) -> HarvestCredentials {
        HarvestCredentials(accessToken: "fixture", accountId: "\(scenario):\(UUID().uuidString)", subdomain: "fixture")
    }

    static func requests(for credentials: HarvestCredentials) -> [URL] {
        recorder.urls(for: credentials.accountId)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let account = request.value(forHTTPHeaderField: "Harvest-Account-Id") ?? ""
        let attempt = Self.recorder.record(url, for: account)
        let scenario = account.components(separatedBy: ":").first ?? ""
        let (status, body) = Self.reply(scenario: scenario, url: url, attempt: attempt)
        let headers = status == 429 ? ["Retry-After": "0"] : [:]
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }

    private static func reply(scenario: String, url: URL, attempt: Int) -> (Int, String) {
        switch scenario {
        case "rateLimited":
            return (429, "{}")
        case "rateLimitedOnce" where attempt == 1:
            return (429, "{}")
        case "unauthorized":
            return (401, "{}")
        case "paging":
            let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "page" })?.value
            return (200, pagedDocuments(kind: url.lastPathComponent, page: page == "2" ? 2 : 1))
        case "exportSkip":
            // Invoice 2 is deleted between listing invoices and fetching its payments.
            if url.path.hasSuffix("invoices/2/payments") { return (404, "{}") }
            if url.lastPathComponent == "payments" {
                return (200, #"{"invoice_payments":[{"id":10}],"next_page":null}"#)
            }
            return (200, #"{"invoices":[{"id":1},{"id":2}],"next_page":null}"#)
        case "nullable":
            return (200, list("invoices", [invoice(id: 1, number: "1", nullableFields: true)], page: 1, nextPage: nil))
        default:
            return (200, #"{"base_uri":"https://fresh.harvestapp.com","full_domain":"fresh.harvestapp.com","name":"Fresh"}"#)
        }
    }

    /// Two pages where document 2 shifts onto page 2 (as when a document is created
    /// mid-fetch) and comes back with a newer number.
    private static func pagedDocuments(kind: String, page: Int) -> String {
        func document(_ id: Int, _ number: String) -> String {
            kind == "estimates"
                ? HarvestAPIStub.estimate(id: id, number: number)
                : HarvestAPIStub.invoice(id: id, number: number, nullableFields: false)
        }
        return page == 1
            ? list(kind, [document(1, "1"), document(2, "2")], page: 1, nextPage: 2)
            : list(kind, [document(2, "2-updated"), document(3, "3")], page: 2, nextPage: nil)
    }

    private static func list(_ key: String, _ documents: [String], page: Int, nextPage: Int?) -> String {
        """
        {"\(key)":[\(documents.joined(separator: ","))],"per_page":2,"total_pages":2,"total_entries":4,
        "next_page":\(nextPage.map(String.init) ?? "null"),"previous_page":null,"page":\(page)}
        """
    }

    private static func invoice(id: Int, number: String, nullableFields: Bool) -> String {
        let optional = nullableFields
            ? #""purchase_order":null,"tax":null,"tax_amount":null,"discount":null,"subject":null,"notes":null,"period_start":null,"period_end":null,"sent_at":null,"paid_at":null,"paid_date":null,"closed_at":null,"line_items":[{"id":9,"kind":"Service","description":null,"quantity":1,"unit_price":10,"amount":10,"taxed":false,"taxed2":false,"project":null}],"#
            : ""
        return """
        {"id":\(id),"client_key":"key\(id)","number":"\(number)","amount":100,"due_amount":100,\(optional)
        "currency":"CHF","state":"open","issue_date":"2026-09-01","due_date":"2026-09-30",
        "created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z","client":{"id":1,"name":"Fixture"}}
        """
    }

    private static func estimate(id: Int, number: String) -> String {
        """
        {"id":\(id),"client_key":"key\(id)","number":"\(number)","amount":100,"currency":"CHF","state":"draft",
        "issue_date":"2026-09-01","created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z",
        "client":{"id":1,"name":"Fixture"}}
        """
    }
}

final class HarvestAPIStubRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String: [URL]] = [:]

    /// Records the request and returns how many this account has made so far.
    func record(_ url: URL, for account: String) -> Int {
        lock.withLock {
            log[account, default: []].append(url)
            return log[account]?.count ?? 0
        }
    }

    func urls(for account: String) -> [URL] {
        lock.withLock { log[account] ?? [] }
    }
}
