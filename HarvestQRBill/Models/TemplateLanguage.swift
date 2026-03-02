//
//  TemplateLanguage.swift
//  HarvestQRBill
//

import Foundation

enum TemplateLanguage: String, Codable, CaseIterable, Sendable {
    case en, de, fr, it

    var displayName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Fran\u{00E7}ais"
        case .it: "Italiano"
        }
    }

    var labels: [String: String] {
        switch self {
        case .en: Self.en_labels
        case .de: Self.de_labels
        case .fr: Self.fr_labels
        case .it: Self.it_labels
        }
    }

    private static let en_labels: [String: String] = [
        "invoice": "Invoice",
        "description": "Description",
        "quantity": "Qty",
        "unitPrice": "Unit Price",
        "rate": "Rate",
        "price": "Price",
        "amount": "Amount",
        "total": "Total",
        "subtotal": "Subtotal",
        "vat": "VAT",
        "discount": "Discount",
        "totalDue": "Total Due",
        "totalHours": "Total Hours",
        "due": "Due",
        "date": "Date",
        "currency": "Currency",
        "from": "From",
        "billTo": "Bill To",
        "details": "Details",
        "iban": "IBAN",
        "paymentDetails": "Payment Details",
        "notes": "Notes",
        "re": "Re",
        "number": "Number",
        "tax": "Tax",
    ]

    private static let de_labels: [String: String] = [
        "invoice": "Rechnung",
        "description": "Beschreibung",
        "quantity": "Menge",
        "unitPrice": "Einzelpreis",
        "rate": "Ansatz",
        "price": "Preis",
        "amount": "Betrag",
        "total": "Total",
        "subtotal": "Zwischensumme",
        "vat": "MwSt.",
        "discount": "Rabatt",
        "totalDue": "Gesamtbetrag",
        "totalHours": "Total Stunden",
        "due": "F\u{00E4}llig",
        "date": "Datum",
        "currency": "W\u{00E4}hrung",
        "from": "Von",
        "billTo": "Rechnung an",
        "details": "Details",
        "iban": "IBAN",
        "paymentDetails": "Zahlungsdetails",
        "notes": "Bemerkungen",
        "re": "Betr.",
        "number": "Nummer",
        "tax": "Steuer",
    ]

    private static let fr_labels: [String: String] = [
        "invoice": "Facture",
        "description": "Description",
        "quantity": "Qt\u{00E9}",
        "unitPrice": "Prix unitaire",
        "rate": "Taux",
        "price": "Prix",
        "amount": "Montant",
        "total": "Total",
        "subtotal": "Sous-total",
        "vat": "TVA",
        "discount": "Remise",
        "totalDue": "Total d\u{00FB}",
        "totalHours": "Total heures",
        "due": "\u{00C9}ch\u{00E9}ance",
        "date": "Date",
        "currency": "Devise",
        "from": "De",
        "billTo": "Facturer \u{00E0}",
        "details": "D\u{00E9}tails",
        "iban": "IBAN",
        "paymentDetails": "D\u{00E9}tails de paiement",
        "notes": "Remarques",
        "re": "Objet",
        "number": "Numéro",
        "tax": "Taxe",
    ]

    private static let it_labels: [String: String] = [
        "invoice": "Fattura",
        "description": "Descrizione",
        "quantity": "Qt\u{00E0}",
        "unitPrice": "Prezzo unitario",
        "rate": "Tariffa",
        "price": "Prezzo",
        "amount": "Importo",
        "total": "Totale",
        "subtotal": "Subtotale",
        "vat": "IVA",
        "discount": "Sconto",
        "totalDue": "Totale dovuto",
        "totalHours": "Ore totali",
        "due": "Scadenza",
        "date": "Data",
        "currency": "Valuta",
        "from": "Da",
        "billTo": "Fatturare a",
        "details": "Dettagli",
        "iban": "IBAN",
        "paymentDetails": "Dettagli di pagamento",
        "notes": "Note",
        "re": "Rif.",
        "number": "Numero",
        "tax": "Imposta",
    ]
}
