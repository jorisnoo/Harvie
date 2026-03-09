//
//  InvoiceTemplate.swift
//  Harvie
//

import Foundation
import SwiftData

struct ColumnVisibility: Codable, Sendable, Equatable {
    var showQuantity: Bool = true
    var showUnitPrice: Bool = true
    var showTotalHours: Bool = false

    nonisolated init(showQuantity: Bool = true, showUnitPrice: Bool = true, showTotalHours: Bool = false) {
        self.showQuantity = showQuantity
        self.showUnitPrice = showUnitPrice
        self.showTotalHours = showTotalHours
    }

    nonisolated static let `default` = ColumnVisibility()

    nonisolated func cssVariables() -> String {
        """
        :root {
            --col-qty-display: \(showQuantity ? "table-cell" : "none");
            --col-price-display: \(showUnitPrice ? "table-cell" : "none");
            --total-hours-display: \(showTotalHours ? "flex" : "none");
        }
        """
    }

    private enum CodingKeys: String, CodingKey {
        case showQuantity, showUnitPrice, showTotalHours
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showQuantity = try container.decodeIfPresent(Bool.self, forKey: .showQuantity) ?? true
        showUnitPrice = try container.decodeIfPresent(Bool.self, forKey: .showUnitPrice) ?? true
        showTotalHours = try container.decodeIfPresent(Bool.self, forKey: .showTotalHours) ?? false
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showQuantity, forKey: .showQuantity)
        try container.encode(showUnitPrice, forKey: .showUnitPrice)
        try container.encode(showTotalHours, forKey: .showTotalHours)
    }
}

@Model
final class InvoiceTemplate {
    var id: UUID
    var name: String
    var htmlContent: String
    var cssContent: String
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date
    var columnVisibilityData: Data?

    var columnVisibility: ColumnVisibility {
        get {
            guard let data = columnVisibilityData else { return .default }
            return (try? JSONDecoder().decode(ColumnVisibility.self, from: data)) ?? .default
        }
        set {
            columnVisibilityData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        htmlContent: String,
        cssContent: String = "",
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.htmlContent = htmlContent
        self.cssContent = cssContent
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns HTML content from disk for user templates, or stored content for built-in.
    func resolvedHTMLContent() -> String {
        if !isBuiltIn, let diskContent = TemplateFileManager.loadHTML(for: id) {
            return diskContent
        }
        return htmlContent
    }

    /// Returns CSS content from disk for user templates, or stored content for built-in.
    func resolvedCSSContent() -> String {
        if !isBuiltIn, let diskContent = TemplateFileManager.loadCSS(for: id) {
            return diskContent
        }
        return cssContent
    }

    func duplicate() -> InvoiceTemplate {
        let copy = InvoiceTemplate(
            name: "\(name) Copy",
            htmlContent: resolvedHTMLContent(),
            cssContent: resolvedCSSContent(),
            isBuiltIn: false
        )
        copy.columnVisibilityData = columnVisibilityData
        return copy
    }
}
