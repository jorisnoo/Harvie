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
    var filenamePattern: String
    var isDemoMode: Bool

    static let defaultFilenamePattern = "Rechnung_{number}_{creditor}"

    static var `default`: AppSettings {
        AppSettings(
            downloadBehavior: .useDefaultFolder,
            defaultDownloadPath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first,
            downloadBookmarkData: nil,
            filenamePattern: defaultFilenamePattern,
            isDemoMode: false
        )
    }

    init(downloadBehavior: DownloadBehavior, defaultDownloadPath: String?, downloadBookmarkData: Data?, filenamePattern: String = defaultFilenamePattern, isDemoMode: Bool = false) {
        self.downloadBehavior = downloadBehavior
        self.defaultDownloadPath = defaultDownloadPath
        self.downloadBookmarkData = downloadBookmarkData
        self.filenamePattern = filenamePattern
        self.isDemoMode = isDemoMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloadBehavior = try container.decode(DownloadBehavior.self, forKey: .downloadBehavior)
        defaultDownloadPath = try container.decodeIfPresent(String.self, forKey: .defaultDownloadPath)
        downloadBookmarkData = try container.decodeIfPresent(Data.self, forKey: .downloadBookmarkData)
        filenamePattern = try container.decodeIfPresent(String.self, forKey: .filenamePattern) ?? Self.defaultFilenamePattern
        isDemoMode = try container.decodeIfPresent(Bool.self, forKey: .isDemoMode) ?? false
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

    func generateFilename(
        invoiceNumber: String,
        creditorName: String,
        clientName: String,
        issueDate: Date
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let sanitize: (String) -> String = { input in
            input
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        }

        var filename = filenamePattern
        filename = filename.replacingOccurrences(of: "{number}", with: invoiceNumber.replacingOccurrences(of: "/", with: "-"))
        filename = filename.replacingOccurrences(of: "{creditor}", with: sanitize(creditorName))
        filename = filename.replacingOccurrences(of: "{client}", with: sanitize(clientName))
        filename = filename.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: issueDate))

        return filename + ".pdf"
    }
}
