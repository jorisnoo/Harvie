//
//  LegacyMigration.swift
//  Harvie
//

import Foundation
import os.log
import Security

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "LegacyMigration")

enum LegacyMigration {
    private static let didMigrateKey = "didMigrateFromHarvestQRBill"
    private static let oldKeychainService = "ch.noordermeer.HarvestQRBill"
    private static let newKeychainService = "app.harvie"

    private static let keychainAccounts = [
        "harvest_credentials",
        "creditor_info",
        "app_settings",
    ]

    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: didMigrateKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: didMigrateKey) }

        migrateKeychain()
        migrateAppSupport()
    }

    private static func migrateKeychain() {
        for account in keychainAccounts {
            guard let data = readKeychain(service: oldKeychainService, account: account) else { continue }

            if writeKeychain(service: newKeychainService, account: account, data: data) {
                deleteKeychain(service: oldKeychainService, account: account)
                logger.info("Migrated keychain item: \(account)")
            }
        }
    }

    private static func migrateAppSupport() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let oldDir = appSupport.appendingPathComponent("HarvestQRBill")
        let newDir = appSupport.appendingPathComponent("Harvie")

        guard FileManager.default.fileExists(atPath: oldDir.path) else { return }

        // If the new directory already exists, merge contents
        if FileManager.default.fileExists(atPath: newDir.path) {
            mergeDirectory(from: oldDir, to: newDir)
        } else {
            do {
                try FileManager.default.moveItem(at: oldDir, to: newDir)
                logger.info("Moved Application Support directory")
            } catch {
                logger.error("Failed to move Application Support: \(error.localizedDescription)")
            }
        }
    }

    private static func mergeDirectory(from source: URL, to destination: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) else { return }

        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if !FileManager.default.fileExists(atPath: target.path) {
                try? FileManager.default.moveItem(at: item, to: target)
            }
        }

        try? FileManager.default.removeItem(at: source)
    }

    // MARK: - Keychain Helpers

    private static func readKeychain(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }

    @discardableResult
    private static func writeKeychain(service: String, account: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecDuplicateItem
    }

    private static func deleteKeychain(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
