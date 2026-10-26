//
//  HarvestRateLimit.swift
//  Harvie
//

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "API")

/// Harvest answers 429 once a token exceeds its request quota. Both API clients
/// send requests through here so rate-limited responses are retried a few times,
/// honouring `Retry-After`. A 429 means the server rejected the request, so
/// retrying mutations is safe too.
enum HarvestRateLimit {
    nonisolated static let maxRetries = 3
    nonisolated static let maxDelay: Double = 30

    /// Sends `request`, retrying rate-limited responses. Returns the last response,
    /// which is still a 429 once the retries are used up. Throws `CancellationError`
    /// when the task is cancelled while waiting.
    nonisolated static func data(
        for request: URLRequest,
        using session: URLSession
    ) async throws -> (Data, URLResponse) {
        var attempt = 0
        var (data, response) = try await session.data(for: request)

        while let http = response as? HTTPURLResponse, http.statusCode == 429, attempt < maxRetries {
            let seconds = delay(for: http, attempt: attempt)
            #if DEBUG
            logger.debug("Rate limited, retrying in \(seconds)s")
            #endif
            try await Task.sleep(for: .seconds(seconds))
            attempt += 1
            (data, response) = try await session.data(for: request)
        }

        return (data, response)
    }

    /// Seconds to wait before retrying: `Retry-After` when Harvest sends it,
    /// otherwise 2, 4, 8… — clamped to `maxDelay`.
    nonisolated static func delay(for response: HTTPURLResponse, attempt: Int) -> Double {
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            .flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        let seconds = retryAfter ?? Double(1 << (attempt + 1))
        return min(max(seconds, 0), maxDelay)
    }
}
