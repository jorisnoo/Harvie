//
//  CachedInvoice.swift
//  HarvestQRBill
//

import Foundation
import SwiftData

@Model
final class CachedInvoice {
    @Attribute(.unique) var id: Int
    var clientKey: String
    var number: String
    var purchaseOrder: String?
    var amount: Decimal
    var dueAmount: Decimal
    var tax: Decimal?
    var taxAmount: Decimal?
    var tax2: Decimal?
    var tax2Amount: Decimal?
    var discount: Decimal?
    var discountAmount: Decimal?
    var subject: String?
    var notes: String?
    var currency: String
    var stateRaw: String
    var periodStart: Date?
    var periodEnd: Date?
    var issueDate: Date
    var dueDate: Date
    var sentAt: Date?
    var paidAt: Date?
    var paidDate: Date?
    var closedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // Client info (flattened)
    var clientId: Int
    var clientName: String

    // Line items stored as JSON data
    var lineItemsData: Data?

    // Cache metadata
    var lastFetched: Date

    var state: InvoiceState {
        InvoiceState(rawValue: stateRaw) ?? .open
    }

    init(from invoice: Invoice) {
        self.id = invoice.id
        self.clientKey = invoice.clientKey
        self.number = invoice.number
        self.purchaseOrder = invoice.purchaseOrder
        self.amount = invoice.amount
        self.dueAmount = invoice.dueAmount
        self.tax = invoice.tax
        self.taxAmount = invoice.taxAmount
        self.tax2 = invoice.tax2
        self.tax2Amount = invoice.tax2Amount
        self.discount = invoice.discount
        self.discountAmount = invoice.discountAmount
        self.subject = invoice.subject
        self.notes = invoice.notes
        self.currency = invoice.currency
        self.stateRaw = invoice.state.rawValue
        self.periodStart = invoice.periodStart
        self.periodEnd = invoice.periodEnd
        self.issueDate = invoice.issueDate
        self.dueDate = invoice.dueDate
        self.sentAt = invoice.sentAt
        self.paidAt = invoice.paidAt
        self.paidDate = invoice.paidDate
        self.closedAt = invoice.closedAt
        self.createdAt = invoice.createdAt
        self.updatedAt = invoice.updatedAt
        self.clientId = invoice.client.id
        self.clientName = invoice.client.name
        self.lastFetched = Date()

        if let lineItems = invoice.lineItems {
            self.lineItemsData = try? JSONEncoder().encode(lineItems)
        }
    }

    func update(from invoice: Invoice) {
        self.clientKey = invoice.clientKey
        self.number = invoice.number
        self.purchaseOrder = invoice.purchaseOrder
        self.amount = invoice.amount
        self.dueAmount = invoice.dueAmount
        self.tax = invoice.tax
        self.taxAmount = invoice.taxAmount
        self.tax2 = invoice.tax2
        self.tax2Amount = invoice.tax2Amount
        self.discount = invoice.discount
        self.discountAmount = invoice.discountAmount
        self.subject = invoice.subject
        self.notes = invoice.notes
        self.currency = invoice.currency
        self.stateRaw = invoice.state.rawValue
        self.periodStart = invoice.periodStart
        self.periodEnd = invoice.periodEnd
        self.issueDate = invoice.issueDate
        self.dueDate = invoice.dueDate
        self.sentAt = invoice.sentAt
        self.paidAt = invoice.paidAt
        self.paidDate = invoice.paidDate
        self.closedAt = invoice.closedAt
        self.createdAt = invoice.createdAt
        self.updatedAt = invoice.updatedAt
        self.clientId = invoice.client.id
        self.clientName = invoice.client.name
        self.lastFetched = Date()

        if let lineItems = invoice.lineItems {
            self.lineItemsData = try? JSONEncoder().encode(lineItems)
        }
    }

    func toInvoice() -> Invoice {
        var lineItems: [LineItem]?
        if let data = lineItemsData {
            lineItems = try? JSONDecoder().decode([LineItem].self, from: data)
        }

        return Invoice(
            id: id,
            clientKey: clientKey,
            number: number,
            purchaseOrder: purchaseOrder,
            amount: amount,
            dueAmount: dueAmount,
            tax: tax,
            taxAmount: taxAmount,
            tax2: tax2,
            tax2Amount: tax2Amount,
            discount: discount,
            discountAmount: discountAmount,
            subject: subject,
            notes: notes,
            currency: currency,
            state: state,
            periodStart: periodStart,
            periodEnd: periodEnd,
            issueDate: issueDate,
            dueDate: dueDate,
            sentAt: sentAt,
            paidAt: paidAt,
            paidDate: paidDate,
            closedAt: closedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            client: ClientReference(id: clientId, name: clientName),
            lineItems: lineItems
        )
    }
}
