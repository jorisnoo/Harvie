import Foundation
import Testing
@testable import Harvie

@Suite("Harvest API")
@MainActor
struct HarvestAPIServiceTests {
    private let api = HarvestAPIService(session: HarvestAPIStub.session())

    @Test("Fetching all invoices walks every page at the largest page size and drops shifted duplicates")
    func fetchAllInvoicesDeduplicates() async throws {
        let credentials = HarvestAPIStub.credentials("paging")
        let invoices = try await api.fetchAllInvoices(credentials: credentials)

        #expect(invoices.map(\.id) == [1, 2, 3])
        #expect(invoices.map(\.number) == ["1", "2-updated", "3"])
        let requests = HarvestAPIStub.requests(for: credentials)
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.query?.contains("per_page=2000") == true })
    }

    @Test("Fetching all estimates drops shifted duplicates")
    func fetchAllEstimatesDeduplicates() async throws {
        let estimates = try await api.fetchAllEstimates(credentials: HarvestAPIStub.credentials("paging"))

        #expect(estimates.map(\.id) == [1, 2, 3])
        #expect(estimates.map(\.number) == ["1", "2-updated", "3"])
    }

    @Test("Invoice lists decode with nullable fields")
    func decodesNullableInvoiceFields() async throws {
        let response = try await api.fetchInvoices(credentials: HarvestAPIStub.credentials("nullable"))
        let invoice = try #require(response.invoices.first)

        #expect(response.nextPage == nil)
        #expect(invoice.subject == nil)
        #expect(invoice.purchaseOrder == nil)
        #expect(invoice.tax == nil)
        #expect(invoice.sentAt == nil)
        #expect(invoice.effectivePaidDate == nil)
        let item = try #require(invoice.lineItems?.first)
        #expect(item.description == nil)
        #expect(item.project == nil)
    }

    @Test("A rate-limited request is retried")
    func retriesRateLimitedRequest() async throws {
        let credentials = HarvestAPIStub.credentials("rateLimitedOnce")
        let company = try await api.fetchCompany(credentials: credentials)

        #expect(company.subdomain == "fresh")
        #expect(HarvestAPIStub.requests(for: credentials).count == 2)
    }

    @Test("A rate-limited mutation is retried")
    func retriesRateLimitedMutation() async throws {
        let credentials = HarvestAPIStub.credentials("rateLimitedOnce")
        try await api.markInvoiceAsSent(invoiceId: 7, credentials: credentials)

        #expect(HarvestAPIStub.requests(for: credentials).count == 2)
    }

    @Test("Retries stop after the cap with a rate-limit error")
    func stopsRetryingAfterCap() async throws {
        let credentials = HarvestAPIStub.credentials("rateLimited")
        do {
            _ = try await api.fetchCompany(credentials: credentials)
            Issue.record("Expected a rate-limit error")
        } catch HarvestAPIService.APIError.rateLimited { }
        #expect(HarvestAPIStub.requests(for: credentials).count == HarvestRateLimit.maxRetries + 1)
    }

    @Test("The raw export client caps rate-limit retries too")
    func rawClientStopsRetryingAfterCap() async throws {
        let client = HarvestRawAPIClient(session: HarvestAPIStub.session())
        let credentials = HarvestAPIStub.credentials("rateLimited")
        do {
            _ = try await client.fetchObject(path: "company", credentials: credentials)
            Issue.record("Expected a rate-limit error")
        } catch HarvestRawAPIClient.RawAPIError.rateLimited { }
        #expect(HarvestAPIStub.requests(for: credentials).count == HarvestRateLimit.maxRetries + 1)
    }

    @Test("Retry-After is honoured but clamped; otherwise back off exponentially")
    func retryDelay() {
        func response(_ retryAfter: String?) -> HTTPURLResponse {
            let headers = retryAfter.map { ["Retry-After": $0] } ?? [:]
            return HTTPURLResponse(url: URL(string: "https://api.harvestapp.com/v2/company")!,
                                   statusCode: 429, httpVersion: nil, headerFields: headers)!
        }

        #expect(HarvestRateLimit.delay(for: response("5"), attempt: 0) == 5)
        #expect(HarvestRateLimit.delay(for: response("3600"), attempt: 0) == HarvestRateLimit.maxDelay)
        #expect(HarvestRateLimit.delay(for: response(nil), attempt: 0) == 2)
        #expect(HarvestRateLimit.delay(for: response(nil), attempt: 2) == 8)
    }
}
