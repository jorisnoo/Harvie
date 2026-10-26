//
//  HarvestDocument.swift
//  Harvie
//

import Foundation

/// A Harvest document listed by the app: an invoice or an estimate.
protocol HarvestDocument: Identifiable where ID == Int {
    var updatedAt: Date { get }
}

extension Array where Element: HarvestDocument {
    /// Drops repeated IDs (pages can shift while paginating), keeping the last copy
    /// at the position of the first.
    func uniquedByID() -> [Element] {
        let latest = Dictionary(map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        var seen = Set<Int>()
        return compactMap { seen.insert($0.id).inserted ? latest[$0.id] : nil }
    }

    /// Replaces documents with fresh copies that are at least as recent, and appends
    /// fresh documents that are not in the list yet.
    func merging(_ fresh: [Element]) -> [Element] {
        var merged = self
        var indexByID = Dictionary(merged.indices.map { (merged[$0].id, $0) }, uniquingKeysWith: { first, _ in first })
        for document in fresh {
            if let index = indexByID[document.id] {
                if document.updatedAt >= merged[index].updatedAt {
                    merged[index] = document
                }
            } else {
                indexByID[document.id] = merged.endIndex
                merged.append(document)
            }
        }
        return merged
    }
}
