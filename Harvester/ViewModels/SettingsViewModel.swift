//
//  SettingsViewModel.swift
//  Harvester
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    var harvestCredentials: HarvestCredentials = HarvestCredentials(
        accessToken: "",
        accountId: "",
        subdomain: ""
    )

    var creditorInfo: CreditorInfo = .empty

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
        do {
            harvestCredentials = try await keychainService.loadHarvestCredentials()
        } catch {
            harvestCredentials = HarvestCredentials(accessToken: "", accountId: "", subdomain: "")
        }

        do {
            creditorInfo = try await keychainService.loadCreditorInfo()
        } catch {
            creditorInfo = .empty
        }
    }

    func saveSettings() async {
        isSaving = true
        saveError = nil

        do {
            try await keychainService.saveHarvestCredentials(harvestCredentials)
            try await keychainService.saveCreditorInfo(creditorInfo)
        } catch {
            saveError = "Failed to save settings: \(error.localizedDescription)"
        }

        isSaving = false
    }

    func testConnection() async {
        guard harvestCredentials.isValid else {
            connectionTestResult = .failure("Please fill in all Harvest credentials.")
            return
        }

        isTestingConnection = true
        connectionTestResult = nil

        do {
            let success = try await apiService.testConnection(credentials: harvestCredentials)
            connectionTestResult = success ? .success : .failure("Connection failed.")
        } catch {
            connectionTestResult = .failure(error.localizedDescription)
        }

        isTestingConnection = false
    }
}
