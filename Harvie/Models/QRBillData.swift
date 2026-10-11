//
//  QRBillData.swift
//  Harvie
//

import Foundation

struct QRBillData {
    let creditorIBAN: String
    let creditorAddress: StructuredAddress
    let amount: Decimal?
    let currency: String
    let debtorAddress: StructuredAddress?
    let reference: String?
    let unstructuredMessage: String?
    let billingInfo: String?

    var qrType: String { "SPC" }
    var version: String { "0200" }
    var coding: Int { 1 }
    var trailer: String { "EPD" }
    var referenceType: ReferenceType { .scor }

    enum ReferenceType: String {
        case qrr = "QRR"
        case scor = "SCOR"
        case non = "NON"
    }

    func generatePayload() -> String {
        var lines: [String] = []

        lines.append(qrType)
        lines.append(version)
        lines.append(String(coding))
        lines.append(creditorIBAN.replacingOccurrences(of: " ", with: ""))

        lines.append(contentsOf: creditorAddress.toPayloadLines())

        lines.append("")
        lines.append("")
        lines.append("")
        lines.append("")
        lines.append("")
        lines.append("")
        lines.append("")

        if let amount {
            lines.append(Self.formatAmount(amount))
        } else {
            lines.append("")
        }
        lines.append(currency)

        if let debtorAddress {
            lines.append(contentsOf: debtorAddress.toPayloadLines())
        } else {
            // Per Swiss QR-bill spec: all 7 debtor address lines must be empty when no debtor
            lines.append("")
            lines.append("")
            lines.append("")
            lines.append("")
            lines.append("")
            lines.append("")
            lines.append("")
        }

        lines.append(referenceType.rawValue)
        lines.append(reference ?? "")
        lines.append(QRBillText.payloadField(unstructuredMessage ?? "", limit: 140))
        lines.append(trailer)

        if let billingInfo {
            lines.append(QRBillText.payloadField(billingInfo, limit: 140))
        }

        return lines.joined(separator: "\r\n")
    }

    /// The payload amount: ASCII digits, "." and no grouping, whatever the user's locale
    /// (which could otherwise produce e.g. Arabic-Indic digits and an unreadable code).
    static func formatAmount(_ amount: Decimal) -> String {
        amountFormatter.string(from: amount as NSDecimalNumber) ?? ""
    }

    static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        // Matches `CurrencyFormatter.rounded` (NSDecimalRound `.plain`): halves round away from zero.
        formatter.roundingMode = .halfUp
        return formatter
    }()
}

struct StructuredAddress {
    let name: String
    let streetName: String?
    let buildingNumber: String?
    let postalCode: String
    let town: String
    let country: String

    var addressType: String { "S" }

    var isValid: Bool {
        [name, postalCode, town].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && Locale.isoRegionCodes.contains(country.uppercased())
    }

    var streetLine: String? {
        guard let street = streetName, !street.isEmpty else { return nil }
        guard let number = buildingNumber, !number.isEmpty else { return street }
        // Keep building number on the last line when streetName spans multiple lines.
        var lines = street.components(separatedBy: "\n")
        if let last = lines.last {
            lines[lines.count - 1] = "\(last) \(number)"
        }
        return lines.joined(separator: "\n")
    }

    var cityLine: String {
        "\(postalCode) \(town)".trimmingCharacters(in: .whitespaces)
    }

    /// A copy restricted to the characters a QR bill permits, so the slip shows exactly
    /// what the payload encodes. Line breaks stay for the slip's layout.
    func sanitized() -> StructuredAddress {
        StructuredAddress(
            name: QRBillText.sanitize(name),
            streetName: streetName.map(QRBillText.sanitize),
            buildingNumber: buildingNumber.map(QRBillText.sanitize),
            postalCode: QRBillText.sanitize(postalCode),
            town: QRBillText.sanitize(town),
            country: country
        )
    }

    func toPayloadLines() -> [String] {
        // Every field must occupy exactly one line of permitted characters in the QR payload.
        [
            addressType,
            QRBillText.payloadField(name, limit: 70),
            QRBillText.payloadField(streetName ?? "", limit: 70),
            QRBillText.payloadField(buildingNumber ?? "", limit: 16),
            QRBillText.payloadField(postalCode, limit: 16),
            QRBillText.payloadField(town, limit: 35),
            country.uppercased()
        ]
    }
}
