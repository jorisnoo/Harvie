//
//  HarvestRawAPIClient.swift
//  Harvie
//

import Foundation

/// Sibling client to `HarvestAPIService` used by `HarvestExporter` to capture
/// raw, untyped JSON responses for any Harvest endpoint. Returns `Data` only,
/// so all field-by-field decoding lives in the exporter and we keep full fidelity
/// for fields the rest of the app does not model.
actor HarvestRawAPIClient {
    static let shared = HarvestRawAPIClient()

    private let baseURL = URL(string: "https://api.harvestapp.com/v2")!
    private let session: URLSession

    enum RawAPIError: Error, LocalizedError {
        case invalidURL
        case unauthorized
        case notFound
        case rateLimited
        case serverError(Int)
        case malformedResponse
        case missingResourceKey(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return Strings.Errors.invalidURL
            case .unauthorized: return Strings.Errors.unauthorized
            case .notFound: return Strings.Errors.notFound
            case .rateLimited: return Strings.Errors.rateLimited
            case .serverError(let code): return Strings.Errors.serverError(code)
            case .malformedResponse: return Strings.Errors.decodingFailed
            case .missingResourceKey(let key): return "Response missing expected key '\(key)'."
            }
        }
    }

    init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = session ?? URLSession(configuration: config)
    }

    /// Fetches every page of a paginated list endpoint and returns the merged
    /// array of resources, JSON-encoded into a single `Data` blob (a JSON array).
    func fetchAllPages(
        path: String,
        resourceKey: String,
        credentials: HarvestCredentials,
        extraQuery: [URLQueryItem] = [],
        perPage: Int = HarvestAPIService.maxPageSize
    ) async throws -> Data {
        var merged: [Any] = []
        var page = 1

        while true {
            var query = extraQuery
            query.append(URLQueryItem(name: "page", value: String(page)))
            query.append(URLQueryItem(name: "per_page", value: String(perPage)))

            let data = try await performRequest(path: path, credentials: credentials, queryItems: query)

            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw RawAPIError.malformedResponse
            }
            guard let rows = root[resourceKey] as? [Any] else {
                throw RawAPIError.missingResourceKey(resourceKey)
            }
            merged.append(contentsOf: rows)

            // Harvest sets next_page to null on the last page.
            if root["next_page"] is NSNull || root["next_page"] == nil {
                break
            }
            page += 1
        }

        return try JSONSerialization.data(
            withJSONObject: merged,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Fetches a single non-paginated endpoint (e.g. `/company`) and returns
    /// its raw JSON object.
    func fetchObject(
        path: String,
        credentials: HarvestCredentials,
        extraQuery: [URLQueryItem] = []
    ) async throws -> Data {
        let data = try await performRequest(path: path, credentials: credentials, queryItems: extraQuery)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RawAPIError.malformedResponse
        }
        return try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func performRequest(
        path: String,
        credentials: HarvestCredentials,
        queryItems: [URLQueryItem]
    ) async throws -> Data {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true) else {
            throw RawAPIError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw RawAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountId, forHTTPHeaderField: "Harvest-Account-Id")
        request.setValue("Harvie (hello@harvie.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await HarvestRateLimit.data(for: request, using: session)

        guard let http = response as? HTTPURLResponse else {
            throw RawAPIError.malformedResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw RawAPIError.unauthorized
        case 404:
            throw RawAPIError.notFound
        case 429:
            throw RawAPIError.rateLimited
        default:
            throw RawAPIError.serverError(http.statusCode)
        }
    }
}
