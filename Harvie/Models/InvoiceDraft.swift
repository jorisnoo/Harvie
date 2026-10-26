//
//  InvoiceDraft.swift
//  Harvie
//

import Foundation

/// Editable form state for a new invoice. Amounts stay as text until the draft is validated.
struct InvoiceDraft {
    struct Line: Identifiable {
        let id = UUID()
        var kind: String
        var description = ""
        var quantity = "1"
        var unitPrice = ""

        var amount: Decimal? {
            guard let quantity = DecimalInput.parse(quantity),
                  let unitPrice = DecimalInput.parse(unitPrice) else { return nil }
            return quantity * unitPrice
        }
    }

    var clientId: Int?
    var subject = ""
    var issueDate = Date()
    var paymentTerm: PaymentTerm = .net30
    var taxRate = ""
    var notes = ""
    var lines: [Line]

    init(kind: String) {
        lines = [Line(kind: kind)]
    }

    var subtotal: Decimal {
        lines.compactMap(\.amount).reduce(0, +)
    }

    /// The validated request, or `nil` while a client is missing or any amount is invalid.
    var newInvoice: NewInvoice? {
        guard let clientId, !lines.isEmpty else { return nil }

        let trimmedTax = taxRate.trimmingCharacters(in: .whitespaces)
        let tax: Decimal?
        if trimmedTax.isEmpty {
            tax = nil
        } else {
            guard let parsed = DecimalInput.parse(trimmedTax), parsed >= 0 else { return nil }
            tax = parsed
        }

        var lineItems: [NewInvoice.LineItem] = []
        for line in lines {
            guard let quantity = DecimalInput.parse(line.quantity),
                  let unitPrice = DecimalInput.parse(line.unitPrice) else { return nil }
            lineItems.append(.init(
                kind: line.kind,
                description: line.description.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                unitPrice: unitPrice
            ))
        }

        return NewInvoice(
            clientId: clientId,
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            taxRate: tax,
            issueDate: issueDate,
            dueDate: paymentTerm.dueDate(from: issueDate),
            paymentTerm: paymentTerm,
            lineItems: lineItems
        )
    }
}

/// A validated invoice ready to be created in Harvest.
struct NewInvoice: Sendable {
    struct LineItem: Sendable {
        let kind: String
        let description: String
        let quantity: Decimal
        let unitPrice: Decimal
    }

    let clientId: Int
    let subject: String?
    let notes: String?
    let taxRate: Decimal?
    let issueDate: Date
    let dueDate: Date
    let paymentTerm: PaymentTerm
    let lineItems: [LineItem]
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
