//
//  FeatureFlags.swift
//  HarvestQRBill
//

import Foundation

enum FeatureFlags {
    private static var flags: [String: Any]? {
        Bundle.main.infoDictionary?["FeatureFlags"] as? [String: Any]
    }

    static var customPDFTemplates: Bool {
        flags?["customPDFTemplates"] as? Bool ?? false
    }
}
