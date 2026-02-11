//
//  InvoiceTemplate.swift
//  HarvestQRBill
//

import Foundation
import SwiftData

struct ColumnVisibility: Codable, Sendable {
    var showQuantity: Bool = true
    var showUnitPrice: Bool = true
    var showTotalHours: Bool = false

    static let `default` = ColumnVisibility()

    func cssVariables() -> String {
        """
        :root {
            --col-qty-display: \(showQuantity ? "table-cell" : "none");
            --col-price-display: \(showUnitPrice ? "table-cell" : "none");
            --total-hours-display: \(showTotalHours ? "flex" : "none");
        }
        """
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

    func duplicate() -> InvoiceTemplate {
        let copy = InvoiceTemplate(
            name: "\(name) Copy",
            htmlContent: htmlContent,
            cssContent: cssContent,
            isBuiltIn: false
        )
        copy.columnVisibilityData = columnVisibilityData
        return copy
    }
}
