//
//  DocumentListSupport.swift
//  Harvie
//

import Foundation

/// Fetches each ID with at most `maxConcurrent` requests in flight, starting the next
/// request as soon as one finishes. Failures are returned rather than dropped.
@MainActor
func fetchEach<Document: Sendable>(
    _ ids: Set<Int>,
    maxConcurrent: Int = 4,
    fetch: @escaping @Sendable (Int) async throws -> Document
) async -> (documents: [Document], failures: [(id: Int, error: any Error)]) {
    var documents: [Document] = []
    var failures: [(id: Int, error: any Error)] = []

    await withTaskGroup(of: (id: Int, result: Result<Document, any Error>).self) { group in
        var pending = ids.makeIterator()
        var inFlight = 0

        while true {
            while inFlight < maxConcurrent, let id = pending.next() {
                group.addTask {
                    do {
                        let document = try await fetch(id)
                        return (id: id, result: .success(document))
                    } catch {
                        return (id: id, result: .failure(error))
                    }
                }
                inFlight += 1
            }

            guard let finished = await group.next() else { break }
            inFlight -= 1
            switch finished.result {
            case .success(let document): documents.append(document)
            case .failure(let error): failures.append((id: finished.id, error: error))
            }
        }
    }

    return (documents: documents, failures: failures)
}

/// Progress and error state for batch actions on the selected documents of a list.
@MainActor
protocol BatchUpdating: AnyObject {
    var isUpdating: Bool { get set }
    var updateError: String? { get set }
    var showUpdateSuccess: Bool { get set }
    var updatedCount: Int { get set }
    var updateTotalCount: Int { get set }
    var appSettings: AppSettings { get }

    func getCredentials() async throws -> HarvestCredentials
}

extension BatchUpdating {
    /// Runs `operation` on each ID in turn, stopping at the first failure, then refreshes
    /// every document it attempted — after a failure too, since earlier ones did change.
    /// An empty batch completes immediately so its confirmation sheet still closes.
    func performBatchOperation(
        on ids: [Int],
        operation: (Int, HarvestCredentials) async throws -> Void,
        refresh: (Set<Int>) async -> Void
    ) async {
        guard !isUpdating else { return }

        updateError = nil
        updatedCount = 0
        updateTotalCount = ids.count

        guard !ids.isEmpty else {
            showUpdateSuccess = true
            return
        }

        #if DEBUG
        if appSettings.isDemoMode {
            showUpdateSuccess = true
            return
        }
        #endif

        isUpdating = true
        var attempted: Set<Int> = []

        do {
            let credentials = try await getCredentials()
            for id in ids {
                attempted.insert(id)
                try await operation(id, credentials)
                updatedCount += 1
            }
            showUpdateSuccess = true
        } catch {
            updateError = error.localizedDescription
        }

        if !attempted.isEmpty {
            await refresh(attempted)
        }
        isUpdating = false
    }
}
