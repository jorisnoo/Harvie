//
//  TemplateLanguage.swift
//  Harvie
//

import Foundation

enum TemplateLanguage: String, Codable, CaseIterable, Sendable {
    case en, de, fr, it

    struct QRBillLabels {
        let receipt, paymentPart, accountPayableTo, reference: String
        let additionalInfo, payableBy, payableByPlaceholder: String
        let currency, amount, invoice: String
    }

    nonisolated var qrBillLabels: QRBillLabels {
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

    nonisolated var paidMark: String {
        switch self {
        case .en: "PAID"
        case .de: "BEZAHLT"
        case .fr: "PAYÉ"
        case .it: "PAGATO"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Fran\u{00E7}ais"
        case .it: "Italiano"
        }
    }

    nonisolated var labels: [String: String] {
        switch self {
        case .en: Self.en_labels
        case .de: Self.de_labels
        case .fr: Self.fr_labels
        case .it: Self.it_labels
        }
    }

    nonisolated private static let en_labels: [String: String] = [
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

    nonisolated private static let de_labels: [String: String] = [
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

    nonisolated private static let fr_labels: [String: String] = [
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

    nonisolated private static let it_labels: [String: String] = [
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

    // MARK: - Label Keys (ordered for UI display)

    nonisolated static let templateLabelKeys: [String] = [
        "invoice", "number", "date", "due", "from", "billTo", "re",
        "description", "quantity", "unitPrice", "rate", "price", "amount",
        "subtotal", "discount", "vat", "tax", "total", "totalDue", "totalHours",
        "currency", "details", "iban", "paymentDetails", "notes",
    ]

    nonisolated static let qrBillLabelKeys: [String] = [
        "qr.receipt", "qr.paymentPart", "qr.accountPayableTo", "qr.reference",
        "qr.additionalInfo", "qr.payableBy", "qr.payableByPlaceholder",
        "qr.currency", "qr.amount", "qr.invoice",
    ]

    // MARK: - Resolved Labels

    nonisolated func resolvedLabels(overrides: [String: [String: String]]?) -> [String: String] {
        var result = labels
        guard let langOverrides = overrides?[rawValue] else { return result }
        for (key, value) in langOverrides where !value.isEmpty && !key.hasPrefix("qr.") {
            result[key] = value
        }
        return result
    }

    nonisolated func resolvedQRBillLabels(overrides: [String: [String: String]]?) -> QRBillLabels {
        let defaults = qrBillLabels
        guard let langOverrides = overrides?[rawValue] else { return defaults }

        func resolve(_ key: String, _ fallback: String) -> String {
            if let v = langOverrides["qr.\(key)"], !v.isEmpty { return v }
            return fallback
        }

        return QRBillLabels(
            receipt: resolve("receipt", defaults.receipt),
            paymentPart: resolve("paymentPart", defaults.paymentPart),
            accountPayableTo: resolve("accountPayableTo", defaults.accountPayableTo),
            reference: resolve("reference", defaults.reference),
            additionalInfo: resolve("additionalInfo", defaults.additionalInfo),
            payableBy: resolve("payableBy", defaults.payableBy),
            payableByPlaceholder: resolve("payableByPlaceholder", defaults.payableByPlaceholder),
            currency: resolve("currency", defaults.currency),
            amount: resolve("amount", defaults.amount),
            invoice: resolve("invoice", defaults.invoice)
        )
    }

    /// Default value for a label key (template or QR bill)
    nonisolated func defaultValue(for key: String) -> String {
        if key.hasPrefix("qr.") {
            let qrKey = String(key.dropFirst(3))
            let l = qrBillLabels
            switch qrKey {
            case "receipt": return l.receipt
            case "paymentPart": return l.paymentPart
            case "accountPayableTo": return l.accountPayableTo
            case "reference": return l.reference
            case "additionalInfo": return l.additionalInfo
            case "payableBy": return l.payableBy
            case "payableByPlaceholder": return l.payableByPlaceholder
            case "currency": return l.currency
            case "amount": return l.amount
            case "invoice": return l.invoice
            default: return ""
            }
        }
        return labels[key] ?? ""
    }
}
