//
//  CachedEstimate.swift
//  Harvie
//

import Foundation
import SwiftData

@Model
final class CachedEstimate {
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    @Attribute(.unique) var id: Int = 0
    var clientKey: String = ""
    var number: String = ""
    var purchaseOrder: String?
    var amount: Decimal = 0
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
    var issueDate: Date = Date.distantPast
    var sentAt: Date?
    var acceptedAt: Date?
    var declinedAt: Date?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    var clientId: Int = 0
    var clientName: String = ""

    var lineItemsData: Data?
    var lastFetched: Date = Date.distantPast

    var state: EstimateState {
        EstimateState(rawValue: stateRaw) ?? .draft
    }

    init(from estimate: Estimate) {
        self.id = estimate.id
        assign(from: estimate)
    }

    func update(from estimate: Estimate) {
        assign(from: estimate)
    }

    private func assign(from estimate: Estimate) {
        clientKey = estimate.clientKey
        number = estimate.number
        purchaseOrder = estimate.purchaseOrder
        amount = estimate.amount
        tax = estimate.tax
        taxAmount = estimate.taxAmount
        tax2 = estimate.tax2
        tax2Amount = estimate.tax2Amount
        discount = estimate.discount
        discountAmount = estimate.discountAmount
        subject = estimate.subject
        notes = estimate.notes
        currency = estimate.currency
        stateRaw = estimate.state.rawValue
        issueDate = estimate.issueDate
        sentAt = estimate.sentAt
        acceptedAt = estimate.acceptedAt
        declinedAt = estimate.declinedAt
        createdAt = estimate.createdAt
        updatedAt = estimate.updatedAt
        clientId = estimate.client.id
        clientName = estimate.client.name
        lastFetched = Date()

        if let lineItems = estimate.lineItems {
            lineItemsData = try? Self.jsonEncoder.encode(lineItems)
        }
    }

    func toEstimate() -> Estimate {
        var lineItems: [LineItem]?
        if let data = lineItemsData {
            lineItems = try? Self.jsonDecoder.decode([LineItem].self, from: data)
        }

        return Estimate(
            id: id,
            clientKey: clientKey,
            number: number,
            purchaseOrder: purchaseOrder,
            amount: amount,
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
            issueDate: issueDate,
            sentAt: sentAt,
            acceptedAt: acceptedAt,
            declinedAt: declinedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            client: ClientReference(id: clientId, name: clientName),
            lineItems: lineItems
        )
    }
}
