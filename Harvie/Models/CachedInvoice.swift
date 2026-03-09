//
//  CachedInvoice.swift
//  Harvie
//

import Foundation
import SwiftData

@Model
final class CachedInvoice {
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    @Attribute(.unique) var id: Int = 0
    var clientKey: String = ""
    var number: String = ""
    var purchaseOrder: String?
    var amount: Decimal = 0
    var dueAmount: Decimal = 0
    var tax: Decimal?
    var taxAmount: Decimal?
    var tax2: Decimal?
    var tax2Amount: Decimal?
    var discount: Decimal?
    var discountAmount: Decimal?
    var subject: String?
    var notes: String?
    var currency: String = ""
    var stateRaw: String = ""
    var periodStart: Date?
    var periodEnd: Date?
    var issueDate: Date = Date.distantPast
    var dueDate: Date = Date.distantPast
    var sentAt: Date?
    var paidAt: Date?
    var paidDate: Date?
    var closedAt: Date?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    // Client info (flattened)
    var clientId: Int = 0
    var clientName: String = ""

    // Line items stored as JSON data
    var lineItemsData: Data?

    // Cache metadata
    var lastFetched: Date = Date.distantPast

    var state: InvoiceState {
        InvoiceState(rawValue: stateRaw) ?? .open
    }

    init(from invoice: Invoice) {
        self.id = invoice.id
        assign(from: invoice)
    }

    func update(from invoice: Invoice) {
        assign(from: invoice)
    }

    private func assign(from invoice: Invoice) {
        clientKey = invoice.clientKey
        number = invoice.number
        purchaseOrder = invoice.purchaseOrder
        amount = invoice.amount
        dueAmount = invoice.dueAmount
        tax = invoice.tax
        taxAmount = invoice.taxAmount
        tax2 = invoice.tax2
        tax2Amount = invoice.tax2Amount
        discount = invoice.discount
        discountAmount = invoice.discountAmount
        subject = invoice.subject
        notes = invoice.notes
        currency = invoice.currency
        stateRaw = invoice.state.rawValue
        periodStart = invoice.periodStart
        periodEnd = invoice.periodEnd
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        sentAt = invoice.sentAt
        paidAt = invoice.paidAt
        paidDate = invoice.paidDate
        closedAt = invoice.closedAt
        createdAt = invoice.createdAt
        updatedAt = invoice.updatedAt
        clientId = invoice.client.id
        clientName = invoice.client.name
        lastFetched = Date()

        if let lineItems = invoice.lineItems {
            lineItemsData = try? Self.jsonEncoder.encode(lineItems)
        }
    }

    func toInvoice() -> Invoice {
        var lineItems: [LineItem]?
        if let data = lineItemsData {
            lineItems = try? Self.jsonDecoder.decode([LineItem].self, from: data)
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
