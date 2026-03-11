//
//  HarvestAPIService.swift
//  Harvie
//

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "API")

actor HarvestAPIService {
    static let shared = HarvestAPIService()

    private let baseURL = URL(string: "https://api.harvestapp.com/v2")!
    private let session: URLSession
    private let sessionDelegate = CertificatePinningDelegate(
        pinnedDomains: ["harvestapp.com"]
    )
    private let decoder: JSONDecoder

    private static nonisolated(unsafe) let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static nonisolated(unsafe) let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        let iso = Self.iso8601Formatter
        let dateOnly = Self.dateOnlyFormatter

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = iso.date(from: dateString) {
                return date
            }

            if let date = dateOnly.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }

    enum APIError: Error, LocalizedError {
        case invalidCredentials
        case invalidURL
        case invalidSubdomain
        case unauthorized
        case notFound
        case serverError(Int)
        case networkError(Error)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return Strings.Errors.invalidCredentials
            case .invalidURL:
                return Strings.Errors.invalidURL
            case .invalidSubdomain:
                return Strings.Errors.invalidSubdomain
            case .unauthorized:
                return Strings.Errors.unauthorized
            case .notFound:
                return Strings.Errors.notFound
            case .serverError(let code):
                return Strings.Errors.serverError(code)
            case .networkError:
                return Strings.Errors.networkFailed
            case .decodingError:
                return Strings.Errors.decodingFailed
            }
        }
    }

    private func makeRequest(
        path: String,
        credentials: HarvestCredentials,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountId, forHTTPHeaderField: "Harvest-Account-Id")
        request.setValue("Harvie (hello@harvie.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func perform<T: Decodable>(
        _ request: URLRequest
    ) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch let DecodingError.keyNotFound(key, context) {
                #if DEBUG
                logger.debug("Missing key '\(key.stringValue)' in \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                #endif
                throw APIError.decodingError(DecodingError.keyNotFound(key, context))
            } catch let DecodingError.typeMismatch(type, context) {
                #if DEBUG
                logger.debug("Type mismatch for \(String(describing: type)) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                #endif
                throw APIError.decodingError(DecodingError.typeMismatch(type, context))
            } catch let DecodingError.valueNotFound(type, context) {
                #if DEBUG
                logger.debug("Value not found for \(String(describing: type)) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                #endif
                throw APIError.decodingError(DecodingError.valueNotFound(type, context))
            } catch {
                #if DEBUG
                logger.debug("Decoding error: \(error.localizedDescription)")
                #endif
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    private func performMutation(_ request: URLRequest) async throws {
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    func fetchInvoices(
        credentials: HarvestCredentials,
        state: InvoiceState? = nil,
        page: Int = 1,
        perPage: Int = 100
    ) async throws -> InvoicesResponse {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]

        if let state {
            queryItems.append(URLQueryItem(name: "state", value: state.rawValue))
        }

        let request = try makeRequest(
            path: "invoices",
            credentials: credentials,
            queryItems: queryItems
        )

        return try await perform(request)
    }

    func fetchAllInvoices(
        credentials: HarvestCredentials,
        state: InvoiceState? = nil
    ) async throws -> [Invoice] {
        var allInvoices: [Invoice] = []
        var page = 1
        var hasMorePages = true

        while hasMorePages {
            let response = try await fetchInvoices(
                credentials: credentials,
                state: state,
                page: page
            )
            allInvoices.append(contentsOf: response.invoices)

            hasMorePages = response.nextPage != nil
            page += 1
        }

        return allInvoices
    }

    func fetchInvoice(
        id: Int,
        credentials: HarvestCredentials
    ) async throws -> Invoice {
        let request = try makeRequest(
            path: "invoices/\(id)",
            credentials: credentials
        )

        return try await perform(request)
    }

    func fetchClient(
        id: Int,
        credentials: HarvestCredentials
    ) async throws -> Client {
        let request = try makeRequest(
            path: "clients/\(id)",
            credentials: credentials
        )

        return try await perform(request)
    }

    /// Validates that a subdomain contains only alphanumeric characters and hyphens
    private nonisolated func isValidSubdomain(_ subdomain: String) -> Bool {
        let pattern = "^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$"
        return subdomain.range(of: pattern, options: .regularExpression) != nil
    }

    nonisolated func buildPDFURL(for invoice: Invoice, subdomain: String) throws -> URL {
        guard isValidSubdomain(subdomain) else {
            throw APIError.invalidSubdomain
        }

        guard let url = URL(string: "https://\(subdomain).harvestapp.com/client/invoices/\(invoice.clientKey).pdf") else {
            throw APIError.invalidURL
        }

        return url
    }

    func updateInvoiceNotes(
        invoiceId: Int,
        notes: String,
        credentials: HarvestCredentials
    ) async throws {
        try await updateInvoice(id: invoiceId, fields: ["notes": notes], credentials: credentials)
    }

    func updateInvoiceSubject(
        invoiceId: Int,
        subject: String,
        credentials: HarvestCredentials
    ) async throws {
        try await updateInvoice(id: invoiceId, fields: ["subject": subject], credentials: credentials)
    }

    func updateInvoiceIssueDate(
        invoiceId: Int,
        issueDate: Date,
        credentials: HarvestCredentials
    ) async throws {
        let dateString = Self.dateOnlyFormatter.string(from: issueDate)
        try await updateInvoice(id: invoiceId, fields: ["issue_date": dateString], credentials: credentials)
    }

    func markInvoiceAsSent(
        invoiceId: Int,
        credentials: HarvestCredentials
    ) async throws {
        try await sendInvoiceEvent(invoiceId: invoiceId, eventType: "send", credentials: credentials)
    }

    func markInvoiceAsDraft(
        invoiceId: Int,
        credentials: HarvestCredentials
    ) async throws {
        try await sendInvoiceEvent(invoiceId: invoiceId, eventType: "draft", credentials: credentials)
    }

    func fetchClientContacts(
        clientId: Int,
        credentials: HarvestCredentials
    ) async throws -> [ClientContact] {
        let request = try makeRequest(
            path: "contacts",
            credentials: credentials,
            queryItems: [URLQueryItem(name: "client_id", value: String(clientId))]
        )
        let response: ClientContactsResponse = try await perform(request)
        return response.contacts
    }

    private func sendInvoiceEvent(
        invoiceId: Int,
        eventType: String,
        credentials: HarvestCredentials
    ) async throws {
        var request = try makeRequest(path: "invoices/\(invoiceId)/messages", credentials: credentials)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["event_type": eventType])
        try await performMutation(request)
    }

    func updateLineItem(
        invoiceId: Int,
        lineItemId: Int,
        description: String? = nil,
        unitPrice: Decimal? = nil,
        allLineItems: [LineItem],
        credentials: HarvestCredentials
    ) async throws {
        var request = try makeRequest(path: "invoices/\(invoiceId)", credentials: credentials)
        request.httpMethod = "PATCH"
        // Include all line items to preserve order
        let payload = LineItemUpdatePayload(lineItems: allLineItems.map { item in
            if item.id == lineItemId {
                return .init(
                    id: item.id,
                    description: description ?? (item.description ?? ""),
                    unitPrice: unitPrice
                )
            }
            return .init(id: item.id, description: item.description ?? "", unitPrice: nil)
        })
        request.httpBody = try JSONEncoder().encode(payload)
        try await performMutation(request)
    }

    private func updateInvoice(
        id: Int,
        fields: [String: String],
        credentials: HarvestCredentials
    ) async throws {
        var request = try makeRequest(path: "invoices/\(id)", credentials: credentials)
        request.httpMethod = "PATCH"
        request.httpBody = try JSONEncoder().encode(fields)
        try await performMutation(request)
    }

    private struct LineItemUpdatePayload: Encodable {
        let lineItems: [Item]

        enum CodingKeys: String, CodingKey {
            case lineItems = "line_items"
        }

        struct Item: Encodable {
            let id: Int
            let description: String
            let unitPrice: Decimal?

            enum CodingKeys: String, CodingKey {
                case id, description
                case unitPrice = "unit_price"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(id, forKey: .id)
                try container.encode(description, forKey: .description)
                try container.encodeIfPresent(unitPrice, forKey: .unitPrice)
            }
        }
    }

    func testConnection(credentials: HarvestCredentials) async throws -> Bool {
        let request = try makeRequest(
            path: "users/me",
            credentials: credentials
        )

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        return httpResponse.statusCode == 200
    }

    func fetchCompany(credentials: HarvestCredentials) async throws -> Company {
        let request = try makeRequest(
            path: "company",
            credentials: credentials
        )

        return try await perform(request)
    }
}

struct Company: Decodable, Sendable {
    let baseUri: String
    let fullDomain: String
    let name: String

    nonisolated var subdomain: String {
        fullDomain.components(separatedBy: ".").first ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case baseUri = "base_uri"
        case fullDomain = "full_domain"
        case name
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseUri = try container.decode(String.self, forKey: .baseUri)
        fullDomain = try container.decode(String.self, forKey: .fullDomain)
        name = try container.decode(String.self, forKey: .name)
    }
}
