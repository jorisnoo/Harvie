import Foundation
import Testing
@testable import Harvie

@Suite("Create invoice", .serialized)
struct CreateInvoiceTests {
    @Test("Creation preserves unique invoice IDs when a refresh has already loaded the invoice", arguments: [false, true])
    @MainActor
    func creationMergesWithLoadedInvoices(alreadyLoaded: Bool) async throws {
        try #require(AppEnvironment.isRunningTests)
        let keychain = KeychainService()
        try await keychain.saveHarvestCredentials(
            HarvestCredentials(accessToken: "fixture", accountId: "fixture", subdomain: "fixture")
        )
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CreateInvoiceURLProtocol.self]
        let vm = InvoicesViewModel(
            apiService: HarvestAPIService(session: URLSession(configuration: config)),
            keychainService: keychain
        )
        await vm.performLoadInvoices()
        try #require(vm.error == nil)
        vm.invoices = [TestDocuments.invoice(id: 1)]
        if alreadyLoaded {
            // A refresh can load the created invoice before the POST response arrives.
            vm.invoices.append(TestDocuments.invoice(id: 9, number: "Earlier snapshot"))
        }

        var draft = InvoiceDraft(kind: "Service")
        draft.clientId = 42
        draft.lines[0].unitPrice = "324"
        try await vm.createInvoice(try #require(draft.newInvoice))

        #expect(vm.invoices.count == 2)
        #expect(Set(vm.invoices.map(\.id)) == [1, 9])
        #expect(vm.invoicesById[9]?.number == "9")
        #expect(vm.invoicesById[9]?.amount == 324)
        #expect(vm.selectedInvoiceIDs == [9])
        #expect(vm.selectedInvoice?.state == .draft)
        #expect(vm.sortedInvoices.contains { $0.id == 9 })
    }

    @Test("Draft without a client is not valid")
    @MainActor
    func draftRequiresClient() {
        var draft = InvoiceDraft(kind: "Service")
        draft.lines[0].unitPrice = "100"

        #expect(draft.newInvoice == nil)

        draft.clientId = 1
        #expect(draft.newInvoice != nil)
    }

    @Test("Draft with an unparseable amount or tax is not valid")
    @MainActor
    func draftRejectsInvalidNumbers() {
        var draft = InvoiceDraft(kind: "Service")
        draft.clientId = 1
        draft.lines[0].unitPrice = "abc"
        #expect(draft.newInvoice == nil)

        draft.lines[0].unitPrice = "100"
        draft.taxRate = "-1"
        #expect(draft.newInvoice == nil)
    }

    @Test("Create sends client, dates, payment term and taxed line items")
    @MainActor
    func createRequestBody() async throws {
        var draft = InvoiceDraft(kind: "Product")
        draft.clientId = 42
        draft.subject = "  Website  "
        draft.issueDate = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        draft.paymentTerm = .net15
        draft.taxRate = "8"
        draft.lines[0].description = "Design"
        draft.lines[0].quantity = "2"
        draft.lines[0].unitPrice = "150"
        let newInvoice = try #require(draft.newInvoice)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CreateInvoiceURLProtocol.self]
        let api = HarvestAPIService(session: URLSession(configuration: config))
        let credentials = HarvestCredentials(accessToken: "fixture", accountId: "fixture", subdomain: "fixture")

        let invoice = try await api.createInvoice(newInvoice, credentials: credentials)
        #expect(invoice.state == .draft)

        let request = try #require(CreateInvoiceURLProtocol.lastRequest())
        #expect(request.method == "POST")
        #expect(request.path == "/v2/invoices")

        let body = try #require(try JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["client_id"] as? Int == 42)
        #expect(body["subject"] as? String == "Website")
        #expect(body["notes"] == nil)
        #expect(body["issue_date"] as? String == "2026-10-01")
        #expect(body["due_date"] as? String == "2026-10-16")
        #expect(body["payment_term"] as? String == "net 15")
        #expect((body["tax"] as? NSNumber)?.decimalValue == 8)

        let lineItems = try #require(body["line_items"] as? [[String: Any]])
        #expect(lineItems.count == 1)
        #expect(lineItems[0]["kind"] as? String == "Product")
        #expect(lineItems[0]["description"] as? String == "Design")
        #expect((lineItems[0]["quantity"] as? NSNumber)?.decimalValue == 2)
        #expect((lineItems[0]["unit_price"] as? NSNumber)?.decimalValue == 150)
        #expect(lineItems[0]["taxed"] as? Bool == true)
    }
}

private final class CreateInvoiceURLProtocol: URLProtocol, @unchecked Sendable {
    struct Captured {
        let method: String?
        let path: String?
        let body: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var captured: Captured?

    static func lastRequest() -> Captured? { lock.withLock { captured } }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if request.httpMethod == "GET" {
            let json = """
            {"invoices":[],"per_page":100,"total_pages":1,"total_entries":0,"page":1}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(json.utf8))
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
        }
        Self.lock.withLock {
            Self.captured = Captured(method: request.httpMethod, path: request.url?.path, body: body)
        }

        let json = """
        {"id":9,"client_key":"fixture","number":"9","amount":324,"due_amount":324,
        "currency":"CHF","state":"draft","issue_date":"2026-10-01","due_date":"2026-10-16",
        "created_at":"2026-10-01T00:00:00Z","updated_at":"2026-10-01T00:00:00Z","client":{"id":42,"name":"Fixture"}}
        """
        let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
