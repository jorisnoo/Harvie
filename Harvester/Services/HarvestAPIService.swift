//
//  HarvestAPIService.swift
//  Harvester
//

import Foundation

actor HarvestAPIService {
    static let shared = HarvestAPIService()

    private let baseURL = URL(string: "https://api.harvestapp.com/v2")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with time first (2017-06-27T16:34:24Z)
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try date-only format (2017-06-27)
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateOnlyFormatter.date(from: dateString) {
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
        case unauthorized
        case notFound
        case serverError(Int)
        case networkError(Error)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "Invalid API credentials. Please check your settings."
            case .unauthorized:
                return "Unauthorized. Please check your API token."
            case .notFound:
                return "Resource not found."
            case .serverError(let code):
                return "Server error (code: \(code))"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
            }
        }
    }

    private func makeRequest(
        path: String,
        credentials: HarvestCredentials,
        queryItems: [URLQueryItem]? = nil
    ) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountId, forHTTPHeaderField: "Harvest-Account-Id")
        request.setValue("Harvester (support@noordermeer.ch)", forHTTPHeaderField: "User-Agent")
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
                print("Missing key '\(key.stringValue)' in \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                throw APIError.decodingError(DecodingError.keyNotFound(key, context))
            } catch let DecodingError.typeMismatch(type, context) {
                print("Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)")
                throw APIError.decodingError(DecodingError.typeMismatch(type, context))
            } catch let DecodingError.valueNotFound(type, context) {
                print("Value not found for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                throw APIError.decodingError(DecodingError.valueNotFound(type, context))
            } catch {
                print("Decoding error: \(error)")
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

        let request = makeRequest(
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
        let request = makeRequest(
            path: "invoices/\(id)",
            credentials: credentials
        )

        return try await perform(request)
    }

    func fetchClient(
        id: Int,
        credentials: HarvestCredentials
    ) async throws -> Client {
        let request = makeRequest(
            path: "clients/\(id)",
            credentials: credentials
        )

        return try await perform(request)
    }

    nonisolated func buildPDFURL(for invoice: Invoice, subdomain: String) -> URL {
        URL(string: "https://\(subdomain).harvestapp.com/client/invoices/\(invoice.clientKey).pdf")!
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

    private func updateInvoice(
        id: Int,
        fields: [String: String],
        credentials: HarvestCredentials
    ) async throws {
        var request = makeRequest(path: "invoices/\(id)", credentials: credentials)
        request.httpMethod = "PATCH"
        request.httpBody = try JSONEncoder().encode(fields)

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

    func testConnection(credentials: HarvestCredentials) async throws -> Bool {
        let request = makeRequest(
            path: "users/me",
            credentials: credentials
        )

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        return httpResponse.statusCode == 200
    }
}
