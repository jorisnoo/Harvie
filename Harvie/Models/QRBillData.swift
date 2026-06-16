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
            lines.append(formatAmount(amount))
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
        lines.append(unstructuredMessage ?? "")
        lines.append(trailer)

        if let billingInfo {
            lines.append(billingInfo)
        }

        return lines.joined(separator: "\r\n")
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        return formatter.string(from: amount as NSDecimalNumber) ?? ""
    }
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
        !name.isEmpty && !postalCode.isEmpty && !town.isEmpty && !country.isEmpty
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

    func toPayloadLines() -> [String] {
        // Swiss QR-bill spec: fields are single-line. Flatten embedded newlines.
        let flatName = name.replacingOccurrences(of: "\n", with: " ")
        let flatStreet = (streetName ?? "").replacingOccurrences(of: "\n", with: " ")
        return [
            addressType,
            String(flatName.prefix(70)),
            String(flatStreet.prefix(70)),
            String((buildingNumber ?? "").prefix(16)),
            String(postalCode.prefix(16)),
            String(town.prefix(35)),
            String(country.prefix(2))
        ]
    }
}
