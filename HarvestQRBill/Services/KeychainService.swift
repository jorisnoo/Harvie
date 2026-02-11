//
//  KeychainService.swift
//  HarvestQRBill
//

import Foundation
import Security

actor KeychainService {
    static let shared = KeychainService()

    private let service = "ch.noordermeer.HarvestQRBill"
    private var cache: [KeychainKey: Data] = [:]

    enum KeychainKey: String {
        case harvestCredentials = "harvest_credentials"
        case creditorInfo = "creditor_info"
        case appSettings = "app_settings"
    }

    enum KeychainError: Error {
        case encodingFailed
        case decodingFailed
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case notFound
    }

    func save<T: Encodable>(_ value: T, for key: KeychainKey) throws {
        let data = try JSONEncoder().encode(value)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key.rawValue,
                kSecValueData as String: data
            ]

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }

        cache[key] = data
    }

    func load<T: Decodable>(for key: KeychainKey) throws -> T {
        if let cached = cache[key] {
            return try JSONDecoder().decode(T.self, from: cached)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.loadFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.decodingFailed
        }

        cache[key] = data

        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }

        cache[key] = nil
    }

    func saveHarvestCredentials(_ credentials: HarvestCredentials) throws {
        try save(credentials, for: .harvestCredentials)
    }

    func loadHarvestCredentials() throws -> HarvestCredentials {
        try load(for: .harvestCredentials)
    }

    func saveCreditorInfo(_ info: CreditorInfo) throws {
        try save(info, for: .creditorInfo)
    }

    func loadCreditorInfo() throws -> CreditorInfo {
        try load(for: .creditorInfo)
    }

    func saveAppSettings(_ settings: AppSettings) throws {
        try save(settings, for: .appSettings)
    }

    func loadAppSettings() throws -> AppSettings {
        try load(for: .appSettings)
    }
}
