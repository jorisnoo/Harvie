//
//  AppSettingsStorage.swift
//  HarvestQRBill
//

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "AppSettingsStorage")

enum AppSettingsStorage {
    private static let key = "appSettings"

    static func load() -> AppSettings {
        if let data = UserDefaults.standard.data(forKey: key) {
            return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? .default
        }

        // Migration: check Keychain for existing settings
        if let migrated = migrateFromKeychain() {
            save(migrated)
            return migrated
        }

        return .default
    }

    static func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func migrateFromKeychain() -> AppSettings? {
        let service = "ch.noordermeer.HarvestQRBill"
        let account = "app_settings"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data,
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return nil
        }

        // Delete from Keychain after successful migration
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        logger.info("Migrated app settings from Keychain to UserDefaults")
        return settings
    }
}
