//
//  FeatureFlags.swift
//  Harvie
//

import Foundation

enum FeatureFlags {
    enum Flag: String, CaseIterable {
        case customPDFTemplates
        case clientOverrides

        var defaultValue: Bool {
            switch self {
            case .customPDFTemplates:
                return false
            case .clientOverrides:
                #if DEBUG
                return true
                #else
                return false
                #endif
            }
        }
    }

    /// Resolution order: debug-build user override → Info.plist → compile-time default.
    static func isEnabled(_ flag: Flag) -> Bool {
        #if DEBUG
        if let value = UserDefaults.standard.object(forKey: userDefaultsKey(flag)) as? Bool {
            return value
        }
        #endif
        if let plist = Bundle.main.infoDictionary?["FeatureFlags"] as? [String: Any],
           let value = plist[flag.rawValue] as? Bool {
            return value
        }
        return flag.defaultValue
    }

    static func setEnabled(_ flag: Flag, _ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey(flag))
    }

    static func resetToDefault(_ flag: Flag) {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey(flag))
    }

    private static func userDefaultsKey(_ flag: Flag) -> String {
        "featureFlag.\(flag.rawValue)"
    }

    static var customPDFTemplates: Bool { isEnabled(.customPDFTemplates) }
    static var clientOverrides: Bool { isEnabled(.clientOverrides) }
}
