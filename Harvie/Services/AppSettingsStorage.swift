//
//  AppSettingsStorage.swift
//  Harvie
//

import Foundation
import os.log
import Security

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "AppSettingsStorage")

enum AppSettingsStorage {
    private static let key = "appSettings"
    private static let didMigrateKeychainKey = "didMigrateAppSettingsFromKeychain"
    private static var testSettings: AppSettings?
    private static var didAttemptKeychainMigration = false

    static func load() -> AppSettings {
        if AppEnvironment.isRunningTests { return testSettings ?? .default }
        migrateFromKeychainIfNeeded()
        guard let data = UserDefaults.standard.data(forKey: key) else { return .default }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? .default
    }

    static func save(_ settings: AppSettings) {
        if AppEnvironment.isRunningTests {
            testSettings = settings
            return
        }
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Settings owns preferences; list view state may have changed since the window opened.
    static func savePreferences(_ preferences: AppSettings) {
        save(mergingPreferences(preferences, into: load()))
    }

    static func mergingPreferences(_ preferences: AppSettings, into latest: AppSettings) -> AppSettings {
        var merged = preferences
        merged.lastSortOption = latest.lastSortOption
        merged.lastSortAscending = latest.lastSortAscending
        merged.lastFilterPeriod = latest.lastFilterPeriod
        merged.lastSelectedPeriod = latest.lastSelectedPeriod
        merged.lastStateFilter = latest.lastStateFilter
        merged.lastSelectedStates = latest.lastSelectedStates
        merged.lastSelectedEstimateStates = latest.lastSelectedEstimateStates
        return merged
    }

    /// Settings recovered from the keychain, or nil to keep `current`. Users whose
    /// settings went missing may have used the app since, so only preferences they
    /// have not changed are restored, and their list state is kept.
    static func restoring(_ legacy: AppSettings, over current: AppSettings?) -> AppSettings? {
        guard let current else { return legacy }
        guard mergingPreferences(.default, into: current) == current else { return nil }
        return mergingPreferences(legacy, into: current)
    }

    // MARK: - Keychain migration

    /// Settings used to live in the keychain under the pre-rename service. Earlier
    /// versions of `LegacyMigration` moved that item to the current service.
    private static let legacyKeychainServices = ["ch.noordermeer.HarvestQRBill", "app.harvie"]
    private static let legacyKeychainAccount = "app_settings"

    /// Runs once per launch until the keychain could be read (it may be locked).
    private static func migrateFromKeychainIfNeeded() {
        guard !didAttemptKeychainMigration, !UserDefaults.standard.bool(forKey: didMigrateKeychainKey) else { return }
        didAttemptKeychainMigration = true

        for service in legacyKeychainServices {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: legacyKeychainAccount,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { continue }
            guard status == errSecSuccess else {
                logger.error("Could not read legacy app settings from Keychain: \(status)")
                return
            }

            if let data = result as? Data,
               let legacy = try? JSONDecoder().decode(AppSettings.self, from: data),
               let restored = restoring(legacy, over: storedSettings()) {
                save(restored)
                logger.info("Migrated app settings from Keychain to UserDefaults")
            }

            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: legacyKeychainAccount,
            ]
            SecItemDelete(deleteQuery as CFDictionary)
        }

        UserDefaults.standard.set(true, forKey: didMigrateKeychainKey)
    }

    private static func storedSettings() -> AppSettings? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) }
    }
}
