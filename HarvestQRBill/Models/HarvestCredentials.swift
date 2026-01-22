//
//  HarvestCredentials.swift
//  HarvestQRBill
//

import Foundation

struct HarvestCredentials: Codable, Sendable {
    var accessToken: String
    var accountId: String
    var subdomain: String

    var canTestConnection: Bool {
        !accessToken.isEmpty && !accountId.isEmpty
    }

    var isValid: Bool {
        canTestConnection && !subdomain.isEmpty
    }
}

struct CreditorInfo: Codable, Sendable {
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

enum DownloadBehavior: String, Codable, CaseIterable, Sendable {
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

struct AppSettings: Codable, Sendable {
    var downloadBehavior: DownloadBehavior
    var defaultDownloadPath: String?
    var downloadBookmarkData: Data?
    var filenamePattern: String
    var dateFormat: String
    var isDemoMode: Bool

    // Persisted filter/sort state
    var lastSortOption: String?
    var lastSortAscending: Bool?
    var lastFilterPeriod: String?
    var lastSelectedPeriod: Date?
    var lastStateFilter: String?

    static let defaultFilenamePattern = "{date}_{number}_{creditor}"
    static let defaultDateFormat = "YYMMDD"

    static var `default`: AppSettings {
        AppSettings(
            downloadBehavior: .useDefaultFolder,
            defaultDownloadPath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first,
            downloadBookmarkData: nil,
            filenamePattern: defaultFilenamePattern,
            dateFormat: defaultDateFormat,
            isDemoMode: false
        )
    }

    init(downloadBehavior: DownloadBehavior, defaultDownloadPath: String?, downloadBookmarkData: Data?, filenamePattern: String = defaultFilenamePattern, dateFormat: String = defaultDateFormat, isDemoMode: Bool = false) {
        self.downloadBehavior = downloadBehavior
        self.defaultDownloadPath = defaultDownloadPath
        self.downloadBookmarkData = downloadBookmarkData
        self.filenamePattern = filenamePattern
        self.dateFormat = dateFormat
        self.isDemoMode = isDemoMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloadBehavior = try container.decode(DownloadBehavior.self, forKey: .downloadBehavior)
        defaultDownloadPath = try container.decodeIfPresent(String.self, forKey: .defaultDownloadPath)
        downloadBookmarkData = try container.decodeIfPresent(Data.self, forKey: .downloadBookmarkData)
        filenamePattern = try container.decodeIfPresent(String.self, forKey: .filenamePattern) ?? Self.defaultFilenamePattern
        dateFormat = try container.decodeIfPresent(String.self, forKey: .dateFormat) ?? Self.defaultDateFormat
        isDemoMode = try container.decodeIfPresent(Bool.self, forKey: .isDemoMode) ?? false
        lastSortOption = try container.decodeIfPresent(String.self, forKey: .lastSortOption)
        lastSortAscending = try container.decodeIfPresent(Bool.self, forKey: .lastSortAscending)
        lastFilterPeriod = try container.decodeIfPresent(String.self, forKey: .lastFilterPeriod)
        lastSelectedPeriod = try container.decodeIfPresent(Date.self, forKey: .lastSelectedPeriod)
        lastStateFilter = try container.decodeIfPresent(String.self, forKey: .lastStateFilter)
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

    private func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        // Convert user format (YYYY, YY, MM, DD) to DateFormatter format (yyyy, yy, MM, dd)
        let format = dateFormat
            .replacingOccurrences(of: "YYYY", with: "yyyy")
            .replacingOccurrences(of: "YY", with: "yy")
            .replacingOccurrences(of: "DD", with: "dd")
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: date)
    }

    func generateFilename(
        invoiceNumber: String,
        creditorName: String,
        clientName: String,
        date: Date,
        issueDate: Date,
        dueDate: Date,
        paidDate: Date?
    ) -> String {
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
        filename = filename.replacingOccurrences(of: "{date}", with: formatDate(date))
        filename = filename.replacingOccurrences(of: "{issueDate}", with: formatDate(issueDate))
        filename = filename.replacingOccurrences(of: "{dueDate}", with: formatDate(dueDate))
        filename = filename.replacingOccurrences(of: "{paidDate}", with: paidDate.map { formatDate($0) } ?? "")

        return filename + ".pdf"
    }
}
