//
//  ClientOverride.swift
//  Harvie
//

import Foundation
import SwiftData

@Model
final class ClientOverride {
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    @Attribute(.unique) var clientId: Int = 0
    var clientName: String = ""

    var templateLanguageRaw: String?
    var columnVisibilityData: Data?
    var labelOverridesData: Data?

    var templateLanguage: TemplateLanguage? {
        get { templateLanguageRaw.flatMap { TemplateLanguage(rawValue: $0) } }
        set { templateLanguageRaw = newValue?.rawValue }
    }

    var columnVisibility: ColumnVisibility? {
        get {
            guard let data = columnVisibilityData else { return nil }
            return try? Self.jsonDecoder.decode(ColumnVisibility.self, from: data)
        }
        set {
            columnVisibilityData = newValue.flatMap { try? Self.jsonEncoder.encode($0) }
        }
    }

    var labelOverrides: [String: [String: String]]? {
        get {
            guard let data = labelOverridesData else { return nil }
            return try? Self.jsonDecoder.decode([String: [String: String]].self, from: data)
        }
        set {
            labelOverridesData = newValue.flatMap { try? Self.jsonEncoder.encode($0) }
        }
    }

    var hasAnyOverride: Bool {
        templateLanguageRaw != nil || columnVisibilityData != nil || labelOverridesData != nil
    }

    init(clientId: Int, clientName: String) {
        self.clientId = clientId
        self.clientName = clientName
    }
}
