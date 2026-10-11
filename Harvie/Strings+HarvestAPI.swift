//
//  Strings+HarvestAPI.swift
//  Harvie
//

import Foundation

extension Strings.Errors {
    nonisolated static let rateLimited = String(localized: "Harvest is receiving too many requests. Please wait a moment and try again.")
}

extension Strings.DataExport {
    nonisolated static func skippedParents(_ parent: String, _ ids: [Int]) -> String {
        let list = ids.map(String.init).joined(separator: ", ")
        return String(localized: "Skipped \(parent.lowercased()) that could no longer be read (IDs: \(list)).")
    }
}
