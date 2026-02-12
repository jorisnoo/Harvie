//
//  TemplateContext.swift
//  HarvestQRBill
//

import Foundation

struct TemplateContext {
    let invoice: InvoiceContext
    let client: ClientContext
    let creditor: CreditorContext
    let lineItems: [[String: Any]]

    struct InvoiceContext {
        let number: String
        let amount: Decimal
        let currency: String
        let subject: String
        let notes: String
        let issueDate: Date
        let dueDate: Date
        let tax: Decimal?
        let taxAmount: Decimal?
        let tax2: Decimal?
        let tax2Amount: Decimal?
        let discount: Decimal?
        let discountAmount: Decimal?
        let subtotal: Decimal
    }

    struct ClientContext {
        let name: String
        let address: String
    }

    struct CreditorContext {
        let name: String
        let iban: String
        let street: String
        let buildingNumber: String
        let postalCode: String
        let town: String
        let country: String
    }

    nonisolated static func from(
        invoice: Invoice,
        creditorInfo: CreditorInfo,
        clientAddress: String? = nil
    ) -> TemplateContext {
        let subtotal: Decimal = {
            if let items = invoice.lineItems {
                return items.reduce(Decimal.zero) { $0 + $1.amount }
            }
            return invoice.amount - (invoice.taxAmount ?? 0) + (invoice.discountAmount ?? 0)
        }()

        let invoiceCtx = InvoiceContext(
            number: invoice.number,
            amount: invoice.amount,
            currency: invoice.currency,
            subject: invoice.subject ?? "",
            notes: invoice.notes ?? "",
            issueDate: invoice.issueDate,
            dueDate: invoice.dueDate,
            tax: invoice.tax,
            taxAmount: invoice.taxAmount,
            tax2: invoice.tax2,
            tax2Amount: invoice.tax2Amount,
            discount: invoice.discount,
            discountAmount: invoice.discountAmount,
            subtotal: subtotal
        )

        let clientCtx = ClientContext(
            name: invoice.client.name,
            address: clientAddress ?? ""
        )

        let creditorCtx = CreditorContext(
            name: creditorInfo.name,
            iban: creditorInfo.iban,
            street: creditorInfo.streetName,
            buildingNumber: creditorInfo.buildingNumber,
            postalCode: creditorInfo.postalCode,
            town: creditorInfo.town,
            country: creditorInfo.country
        )

        let items: [[String: Any]] = (invoice.lineItems ?? []).map { item in
            [
                "description": item.description ?? "",
                "quantity": item.quantity,
                "unitPrice": item.unitPrice,
                "amount": item.amount,
                "kind": item.kind,
                "taxed": item.taxed
            ]
        }

        return TemplateContext(
            invoice: invoiceCtx,
            client: clientCtx,
            creditor: creditorCtx,
            lineItems: items
        )
    }

    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    nonisolated func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "invoice": [
                "number": invoice.number,
                "amount": invoice.amount,
                "currency": invoice.currency,
                "subject": invoice.subject,
                "notes": invoice.notes,
                "issueDate": invoice.issueDate,
                "dueDate": invoice.dueDate,
                "tax": invoice.tax as Any,
                "taxAmount": invoice.taxAmount as Any,
                "tax2": invoice.tax2 as Any,
                "tax2Amount": invoice.tax2Amount as Any,
                "discount": invoice.discount as Any,
                "discountAmount": invoice.discountAmount as Any,
                "subtotal": invoice.subtotal
            ],
            "client": [
                "name": client.name,
                "address": client.address
            ],
            "creditor": [
                "name": creditor.name,
                "iban": creditor.iban,
                "street": creditor.street,
                "buildingNumber": creditor.buildingNumber,
                "postalCode": creditor.postalCode,
                "town": creditor.town,
                "country": creditor.country
            ],
            "lineItems": lineItems
        ]

        // Add convenience booleans for conditionals
        var invoiceDict = dict["invoice"] as! [String: Any]
        invoiceDict["hasNotes"] = !invoice.notes.isEmpty
        invoiceDict["hasSubject"] = !invoice.subject.isEmpty
        invoiceDict["hasTax"] = invoice.tax != nil && invoice.taxAmount != nil
        invoiceDict["hasTax2"] = invoice.tax2 != nil && invoice.tax2Amount != nil
        invoiceDict["hasDiscount"] = invoice.discount != nil && invoice.discountAmount != nil

        let totalHours = lineItems.reduce(Decimal.zero) { sum, item in
            sum + ((item["quantity"] as? Decimal) ?? 0)
        }
        invoiceDict["totalHours"] = totalHours

        dict["invoice"] = invoiceDict

        return dict
    }

    nonisolated static func sampleDictionary() -> [String: Any] {
        let sampleItems: [[String: Any]] = [
            [
                "description": "Web Development Services",
                "quantity": Decimal(40),
                "unitPrice": Decimal(150),
                "amount": Decimal(6000),
                "kind": "Service",
                "taxed": true
            ],
            [
                "description": "UI/UX Design",
                "quantity": Decimal(16),
                "unitPrice": Decimal(120),
                "amount": Decimal(1920),
                "kind": "Service",
                "taxed": true
            ],
            [
                "description": "Project Management",
                "quantity": Decimal(8),
                "unitPrice": Decimal(100),
                "amount": Decimal(800),
                "kind": "Service",
                "taxed": true
            ]
        ]

        return [
            "invoice": [
                "number": "2024-042",
                "amount": Decimal(9427.08),
                "currency": "CHF",
                "subject": "Website Redesign - Phase 2",
                "notes": "Payment terms: 30 days net. Thank you for your business.",
                "issueDate": Date(),
                "dueDate": Date().addingTimeInterval(86400 * 30),
                "tax": Decimal(8.1),
                "taxAmount": Decimal(707.08),
                "tax2": nil as Decimal? as Any,
                "tax2Amount": nil as Decimal? as Any,
                "discount": nil as Decimal? as Any,
                "discountAmount": nil as Decimal? as Any,
                "subtotal": Decimal(8720),
                "hasNotes": true,
                "hasSubject": true,
                "hasTax": true,
                "hasTax2": false,
                "hasDiscount": false,
                "totalHours": Decimal(64)
            ],
            "client": [
                "name": "Acme Corp AG",
                "address": "Bahnhofstrasse 42\n8001 Zurich\nSwitzerland"
            ],
            "creditor": [
                "name": "Design Studio GmbH",
                "iban": "CH93 0076 2011 6238 5295 7",
                "street": "Musterstrasse",
                "buildingNumber": "1",
                "postalCode": "8000",
                "town": "Zurich",
                "country": "CH"
            ],
            "lineItems": sampleItems
        ]
    }
}
