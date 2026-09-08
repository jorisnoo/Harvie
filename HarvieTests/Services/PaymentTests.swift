import Foundation
import Testing
@testable import Harvie

@Suite("Outstanding payments", .serialized)
struct PaymentTests {
    @Test("Retry reads the current balance and does not repeat a recorded payment")
    @MainActor
    func retryAfterPayment() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PaymentURLProtocol.self]
        let api = HarvestAPIService(session: URLSession(configuration: config))
        let credentials = HarvestCredentials(accessToken: "fixture", accountId: "fixture", subdomain: "fixture")
        try await api.payOutstandingBalance(invoiceId: 7, credentials: credentials)
        try await api.payOutstandingBalance(invoiceId: 7, credentials: credentials)
        let amounts = PaymentURLProtocol.fixture.amounts()
        #expect(amounts == [Decimal(string: "42.50")!])
    }
}

private final class PaymentFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Decimal] = []

    func amounts() -> [Decimal] { lock.withLock { recorded } }

    func response(for request: URLRequest, body: Data?) -> Data {
        lock.withLock {
            if request.httpMethod == "POST" {
                if let body, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                   let amount = json["amount"] as? NSNumber {
                    recorded.append(amount.decimalValue)
                }
                return Data("{}".utf8)
            }
            let json = """
            {"id":7,"client_key":"fixture","number":"7","amount":100,"due_amount":\(recorded.isEmpty ? "42.50" : "0"),
            "currency":"CHF","state":"\(recorded.isEmpty ? "open" : "paid")","issue_date":"2026-09-01","due_date":"2026-09-30",
            "created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z","client":{"id":1,"name":"Fixture"}}
            """
            return Data(json.utf8)
        }
    }
}

private final class PaymentURLProtocol: URLProtocol, @unchecked Sendable {
    static let fixture = PaymentFixture()
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            body = data
        }
        let data = Self.fixture.response(for: request, body: body)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
