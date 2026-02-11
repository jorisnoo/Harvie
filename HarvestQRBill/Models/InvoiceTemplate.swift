//
//  InvoiceTemplate.swift
//  HarvestQRBill
//

import Foundation
import SwiftData

@Model
final class InvoiceTemplate {
    var id: UUID
    var name: String
    var htmlContent: String
    var cssContent: String
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date

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
        InvoiceTemplate(
            name: "\(name) Copy",
            htmlContent: htmlContent,
            cssContent: cssContent,
            isBuiltIn: false
        )
    }
}
