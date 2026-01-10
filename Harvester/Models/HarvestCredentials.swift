//
//  HarvestCredentials.swift
//  Harvester
//

import Foundation

struct HarvestCredentials: Codable {
    var accessToken: String
    var accountId: String
    var subdomain: String

    var isValid: Bool {
        !accessToken.isEmpty && !accountId.isEmpty && !subdomain.isEmpty
    }
}

struct CreditorInfo: Codable {
    var iban: String
    var name: String
    var streetName: String
    var buildingNumber: String
    var postalCode: String
    var town: String
    var country: String

    var isValid: Bool {
        !iban.isEmpty && !name.isEmpty && !postalCode.isEmpty && !town.isEmpty && !country.isEmpty
    }

    var structuredAddress: StructuredAddress {
        StructuredAddress(
            name: name,
            streetName: streetName.isEmpty ? nil : streetName,
            buildingNumber: buildingNumber.isEmpty ? nil : buildingNumber,
            postalCode: postalCode,
            town: town,
            country: country
        )
    }

    static var empty: CreditorInfo {
        CreditorInfo(
            iban: "",
            name: "",
            streetName: "",
            buildingNumber: "",
            postalCode: "",
            town: "",
            country: "CH"
        )
    }
}
