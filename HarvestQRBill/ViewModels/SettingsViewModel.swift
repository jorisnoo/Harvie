//
//  SettingsViewModel.swift
//  HarvestQRBill
//

import Foundation
import os.log
import SwiftUI

extension Notification.Name {
    static let menuRefreshTriggered = Notification.Name("menuRefreshTriggered")
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "Settings")

@Observable
@MainActor
final class SettingsViewModel {
    var harvestCredentials: HarvestCredentials = HarvestCredentials(
        accessToken: "",
        accountId: "",
        subdomain: ""
    )

    var creditorInfo: CreditorInfo = .empty
    var appSettings: AppSettings = .default

    var isTestingConnection = false
    var connectionTestResult: ConnectionTestResult?
    var isSaving = false
    var saveError: String?

    enum ConnectionTestResult: Equatable {
        case success
        case failure(String)
    }

    private let keychainService = KeychainService.shared
    private let apiService = HarvestAPIService.shared

    func loadSettings() async {
        harvestCredentials = (try? await keychainService.loadHarvestCredentials())
            ?? HarvestCredentials(accessToken: "", accountId: "", subdomain: "")
        creditorInfo = (try? await keychainService.loadCreditorInfo()) ?? .empty
        appSettings = (try? await keychainService.loadAppSettings()) ?? .default
    }

    func saveSettings() async {
        isSaving = true
        saveError = nil

        do {
            try await keychainService.saveHarvestCredentials(harvestCredentials)
            try await keychainService.saveCreditorInfo(creditorInfo)
            try await keychainService.saveAppSettings(appSettings)
            Analytics.settingsSaved()
        } catch {
            #if DEBUG
            logger.error("Failed to save settings: \(error.localizedDescription)")
            #endif
            saveError = "Failed to save settings. Please try again."
        }

        isSaving = false
    }

    func testConnection() async {
        guard harvestCredentials.canTestConnection else {
            connectionTestResult = .failure("Please fill in Access Token and Account ID.")
            return
        }

        isTestingConnection = true
        connectionTestResult = nil

        do {
            let success = try await apiService.testConnection(credentials: harvestCredentials)
            if success {
                let company = try await apiService.fetchCompany(credentials: harvestCredentials)
                harvestCredentials.subdomain = company.subdomain
                connectionTestResult = .success
                Analytics.harvestConnected()
            } else {
                connectionTestResult = .failure("Connection failed.")
            }
        } catch let apiError as HarvestAPIService.APIError {
            // Use the sanitized error descriptions from APIError
            connectionTestResult = .failure(apiError.localizedDescription)
        } catch {
            #if DEBUG
            logger.error("Connection test failed: \(error.localizedDescription)")
            #endif
            connectionTestResult = .failure("Connection failed. Please check your network.")
        }

        isTestingConnection = false
    }

    func selectDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select default download folder for invoices"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            appSettings.defaultDownloadPath = url.path
            // Create security-scoped bookmark for sandboxed access
            if let bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                appSettings.downloadBookmarkData = bookmarkData
            }
        }
    }
}
