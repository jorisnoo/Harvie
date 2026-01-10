//
//  Invoice.swift
//  Harvester
//

import Foundation

struct InvoicesResponse: Codable {
    let invoices: [Invoice]
    let perPage: Int
    let totalPages: Int
    let totalEntries: Int
    let nextPage: Int?
    let previousPage: Int?
    let page: Int

    enum CodingKeys: String, CodingKey {
        case invoices
        case perPage = "per_page"
        case totalPages = "total_pages"
        case totalEntries = "total_entries"
        case nextPage = "next_page"
        case previousPage = "previous_page"
        case page
    }
}

struct Invoice: Codable, Identifiable, Hashable {
    static func == (lhs: Invoice, rhs: Invoice) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: Int
    let clientKey: String
    let number: String
    let purchaseOrder: String?
    let amount: Decimal
    let dueAmount: Decimal
    let tax: Decimal?
    let taxAmount: Decimal?
    let tax2: Decimal?
    let tax2Amount: Decimal?
    let discount: Decimal?
    let discountAmount: Decimal?
    let subject: String?
    let notes: String?
    let currency: String
    let state: InvoiceState
    let periodStart: Date?
    let periodEnd: Date?
    let issueDate: Date
    let dueDate: Date
    let sentAt: Date?
    let paidAt: Date?
    let paidDate: Date?
    let closedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let client: ClientReference
    let lineItems: [LineItem]?

    enum CodingKeys: String, CodingKey {
        case id, number, amount, tax, discount, subject, notes, currency, state
        case clientKey = "client_key"
        case purchaseOrder = "purchase_order"
        case dueAmount = "due_amount"
        case taxAmount = "tax_amount"
        case tax2
        case tax2Amount = "tax2_amount"
        case discountAmount = "discount_amount"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case issueDate = "issue_date"
        case dueDate = "due_date"
        case sentAt = "sent_at"
        case paidAt = "paid_at"
        case paidDate = "paid_date"
        case closedAt = "closed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case client
        case lineItems = "line_items"
    }
}

enum InvoiceState: String, Codable {
    case draft
    case open
    case paid
    case closed
}

struct LineItem: Codable, Identifiable {
    let id: Int
    let kind: String
    let description: String?
    let quantity: Decimal
    let unitPrice: Decimal
    let amount: Decimal
    let taxed: Bool
    let taxed2: Bool
    let project: ProjectReference?

    enum CodingKeys: String, CodingKey {
        case id, kind, description, quantity, amount, taxed, taxed2, project
        case unitPrice = "unit_price"
    }
}

struct ProjectReference: Codable {
    let id: Int
    let name: String
    let code: String?
}
