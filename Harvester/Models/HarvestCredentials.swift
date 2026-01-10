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

enum DownloadBehavior: String, Codable, CaseIterable {
    case askEachTime = "ask"
    case useDefaultFolder = "default"

    var displayName: String {
        switch self {
        case .askEachTime:
            return "Ask each time"
        case .useDefaultFolder:
            return "Save to default folder"
        }
    }
}

struct AppSettings: Codable {
    var downloadBehavior: DownloadBehavior
    var defaultDownloadPath: String?
    var downloadBookmarkData: Data?

    static var `default`: AppSettings {
        AppSettings(
            downloadBehavior: .useDefaultFolder,
            defaultDownloadPath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first,
            downloadBookmarkData: nil
        )
    }

    var downloadURL: URL? {
        // Try to resolve from bookmark first (for sandboxed access)
        if let bookmarkData = downloadBookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }
        }
        // Fallback to path (works for Downloads folder)
        guard let path = defaultDownloadPath else { return nil }
        return URL(fileURLWithPath: path)
    }
}
