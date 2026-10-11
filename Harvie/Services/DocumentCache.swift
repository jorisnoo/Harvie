//
//  DocumentCache.swift
//  Harvie
//

import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "DocumentCache")

/// A SwiftData row caching one Harvest document for one account.
protocol CachedDocument: PersistentModel {
    associatedtype Document: HarvestDocument

    var documentID: Int { get }
    var accountId: String { get set }
    var lastFetched: Date { get }

    init(from document: Document, accountId: String)
    func update(from document: Document)
    func toDocument() -> Document
}

/// The on-disk cache of one document type, partitioned by Harvest account.
/// Failures are logged: the cache only speeds up showing the list.
@MainActor
struct DocumentCache<Cached: CachedDocument> {
    let context: ModelContext

    /// The account's cached documents, and when the oldest of them was fetched;
    /// nil when the cache cannot be read.
    func load(accountId: String) -> (documents: [Cached.Document], lastFetched: Date?)? {
        do {
            let rows = try context.fetch(FetchDescriptor<Cached>()).filter { $0.accountId == accountId }
            return (documents: rows.map { $0.toDocument() }, lastFetched: rows.map(\.lastFetched).min())
        } catch {
            logger.warning("Failed to load \(String(describing: Cached.self)): \(error.localizedDescription)")
            return nil
        }
    }

    /// Upserts `documents` for the account. A full fetch (`replaceAll`) also drops the
    /// account's rows that are no longer on the server, plus legacy rows without an owner.
    func store(_ documents: [Cached.Document], accountId: String, replaceAll: Bool) {
        let existing = (try? context.fetch(FetchDescriptor<Cached>())) ?? []
        let existingByID = Dictionary(existing.map { ($0.documentID, $0) }, uniquingKeysWith: { first, _ in first })

        for document in documents {
            if let cached = existingByID[document.id] {
                cached.accountId = accountId
                cached.update(from: document)
            } else {
                context.insert(Cached(from: document, accountId: accountId))
            }
        }

        if replaceAll {
            let fetchedIDs = Set(documents.map(\.id))
            for cached in existing where (cached.accountId == accountId || cached.accountId.isEmpty) && !fetchedIDs.contains(cached.documentID) {
                context.delete(cached)
            }
        }

        save()
    }

    /// Deletes every cached document that does not belong to `accountId` (all of them when nil).
    func purge(keeping accountId: String?) {
        let rows = (try? context.fetch(FetchDescriptor<Cached>())) ?? []
        for cached in rows where cached.accountId != accountId {
            context.delete(cached)
        }
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            logger.warning("Failed to save \(String(describing: Cached.self)): \(error.localizedDescription)")
        }
    }
}
