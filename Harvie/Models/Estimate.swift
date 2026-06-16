//
//  Estimate.swift
//  Harvie
//

import Foundation

struct EstimatesResponse: Codable, Sendable {
    let estimates: [Estimate]
    let perPage: Int
    let totalPages: Int
    let totalEntries: Int
    let nextPage: Int?
    let previousPage: Int?
    let page: Int

    private enum CodingKeys: String, CodingKey {
        case estimates
        case perPage = "per_page"
        case totalPages = "total_pages"
        case totalEntries = "total_entries"
        case nextPage = "next_page"
        case previousPage = "previous_page"
        case page
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        estimates = try container.decode([Estimate].self, forKey: .estimates)
        perPage = try container.decode(Int.self, forKey: .perPage)
        totalPages = try container.decode(Int.self, forKey: .totalPages)
        totalEntries = try container.decode(Int.self, forKey: .totalEntries)
        nextPage = try container.decodeIfPresent(Int.self, forKey: .nextPage)
        previousPage = try container.decodeIfPresent(Int.self, forKey: .previousPage)
        page = try container.decode(Int.self, forKey: .page)
    }
}

struct Estimate: Codable, Identifiable, Hashable, Sendable {
    static func == (lhs: Estimate, rhs: Estimate) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(updatedAt)
    }

    let id: Int
    let clientKey: String
    let number: String
    let purchaseOrder: String?
    let amount: Decimal
    let tax: Decimal?
    let taxAmount: Decimal?
    let tax2: Decimal?
    let tax2Amount: Decimal?
    let discount: Decimal?
    let discountAmount: Decimal?
    let subject: String?
    let notes: String?
    let currency: String
    let state: EstimateState
    let issueDate: Date
    let sentAt: Date?
    let acceptedAt: Date?
    let declinedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let client: ClientReference
    let lineItems: [LineItem]?

    init(
        id: Int, clientKey: String, number: String, purchaseOrder: String? = nil,
        amount: Decimal,
        tax: Decimal? = nil, taxAmount: Decimal? = nil,
        tax2: Decimal? = nil, tax2Amount: Decimal? = nil,
        discount: Decimal? = nil, discountAmount: Decimal? = nil,
        subject: String? = nil, notes: String? = nil,
        currency: String, state: EstimateState,
        issueDate: Date,
        sentAt: Date? = nil, acceptedAt: Date? = nil, declinedAt: Date? = nil,
        createdAt: Date, updatedAt: Date,
        client: ClientReference, lineItems: [LineItem]? = nil
    ) {
        self.id = id
        self.clientKey = clientKey
        self.number = number
        self.purchaseOrder = purchaseOrder
        self.amount = amount
        self.tax = tax
        self.taxAmount = taxAmount
        self.tax2 = tax2
        self.tax2Amount = tax2Amount
        self.discount = discount
        self.discountAmount = discountAmount
        self.subject = subject
        self.notes = notes
        self.currency = currency
        self.state = state
        self.issueDate = issueDate
        self.sentAt = sentAt
        self.acceptedAt = acceptedAt
        self.declinedAt = declinedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.client = client
        self.lineItems = lineItems
    }

    private enum CodingKeys: String, CodingKey {
        case id, number, amount, tax, discount, subject, notes, currency, state
        case clientKey = "client_key"
        case purchaseOrder = "purchase_order"
        case taxAmount = "tax_amount"
        case tax2
        case tax2Amount = "tax2_amount"
        case discountAmount = "discount_amount"
        case issueDate = "issue_date"
        case sentAt = "sent_at"
        case acceptedAt = "accepted_at"
        case declinedAt = "declined_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case client
        case lineItems = "line_items"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        clientKey = try container.decode(String.self, forKey: .clientKey)
        number = try container.decode(String.self, forKey: .number)
        purchaseOrder = try container.decodeIfPresent(String.self, forKey: .purchaseOrder)
        amount = try container.decode(Decimal.self, forKey: .amount)
        tax = try container.decodeIfPresent(Decimal.self, forKey: .tax)
        taxAmount = try container.decodeIfPresent(Decimal.self, forKey: .taxAmount)
        tax2 = try container.decodeIfPresent(Decimal.self, forKey: .tax2)
        tax2Amount = try container.decodeIfPresent(Decimal.self, forKey: .tax2Amount)
        discount = try container.decodeIfPresent(Decimal.self, forKey: .discount)
        discountAmount = try container.decodeIfPresent(Decimal.self, forKey: .discountAmount)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        currency = try container.decode(String.self, forKey: .currency)
        state = try container.decode(EstimateState.self, forKey: .state)
        issueDate = try container.decode(Date.self, forKey: .issueDate)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
        acceptedAt = try container.decodeIfPresent(Date.self, forKey: .acceptedAt)
        declinedAt = try container.decodeIfPresent(Date.self, forKey: .declinedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        client = try container.decode(ClientReference.self, forKey: .client)
        lineItems = try container.decodeIfPresent([LineItem].self, forKey: .lineItems)
    }
}

enum EstimateState: String, Codable, CaseIterable, Sendable {
    case draft
    case sent
    case accepted
    case declined

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .sent: "Sent"
        case .accepted: "Accepted"
        case .declined: "Declined"
        }
    }
}
