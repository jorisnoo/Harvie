//
//  TemplateLanguage.swift
//  HarvestQRBill
//

import Foundation

enum TemplateLanguage: String, Codable, CaseIterable, Sendable {
    case en, de, fr, it

    struct QRBillLabels {
        let receipt, paymentPart, accountPayableTo, reference: String
        let additionalInfo, payableBy, payableByPlaceholder: String
        let currency, amount, invoice: String
    }

    var qrBillLabels: QRBillLabels {
        switch self {
        case .de:
            QRBillLabels(
                receipt: "Empfangsschein", paymentPart: "Zahlteil",
                accountPayableTo: "Konto / Zahlbar an", reference: "Referenz",
                additionalInfo: "Zusätzliche Informationen",
                payableBy: "Zahlbar durch", payableByPlaceholder: "Zahlbar durch (Name/Adresse)",
                currency: "Währung", amount: "Betrag", invoice: "Rechnung"
            )
        case .fr:
            QRBillLabels(
                receipt: "Récépissé", paymentPart: "Section paiement",
                accountPayableTo: "Compte / Payable à", reference: "Référence",
                additionalInfo: "Informations supplémentaires",
                payableBy: "Payable par", payableByPlaceholder: "Payable par (nom/adresse)",
                currency: "Monnaie", amount: "Montant", invoice: "Facture"
            )
        case .it:
            QRBillLabels(
                receipt: "Ricevuta", paymentPart: "Sezione pagamento",
                accountPayableTo: "Conto / Pagabile a", reference: "Riferimento",
                additionalInfo: "Informazioni supplementari",
                payableBy: "Pagabile da", payableByPlaceholder: "Pagabile da (nome/indirizzo)",
                currency: "Valuta", amount: "Importo", invoice: "Fattura"
            )
        case .en:
            QRBillLabels(
                receipt: "Receipt", paymentPart: "Payment part",
                accountPayableTo: "Account / Payable to", reference: "Reference",
                additionalInfo: "Additional information",
                payableBy: "Payable by", payableByPlaceholder: "Payable by (name/address)",
                currency: "Currency", amount: "Amount", invoice: "Invoice"
            )
        }
    }

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
