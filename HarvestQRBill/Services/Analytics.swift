//
//  Analytics.swift
//  HarvestQRBill
//

import AviaryInsights
import Foundation

enum Analytics {
    private static var isEnabled: Bool {
        #if DEBUG
        return false
        #else
        return Bundle.main.infoDictionary?["AnalyticsEnabled"] as? Bool ?? false
        #endif
    }

    private static var serverURL: URL {
        let urlString = Bundle.main.infoDictionary?["AnalyticsServerURL"] as? String
            ?? "https://plausible.io/api"
        return URL(string: urlString)!
    }

    private static var domain: String {
        Bundle.main.infoDictionary?["AnalyticsDomain"] as? String
            ?? Bundle.main.bundleIdentifier?.lowercased()
            ?? "unknown"
    }

    private static var distribution: String {
        #if APP_STORE
        "app_store"
        #else
        "direct"
        #endif
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private static let plausible: Plausible? = {
        guard isEnabled else { return nil }
        return Plausible(
            defaultDomain: domain,
            serverURL: serverURL
        )
    }()

    static func track(_ name: String, path: String = "/", props: [String: String]? = nil) {
        guard let plausible else { return }
        var allProps = props ?? [:]
        allProps["distribution"] = distribution
        allProps["version"] = appVersion
        let event = Event(
            url: "app://harvestqrbill\(path)",
            name: name,
            props: allProps
        )
        plausible.postEvent(event)
    }

    static func appOpened() {
        track("pageview")
    }

    static func pdfExported(count: Int = 1) {
        track("PDF Export", props: ["count": "\(count)"])
    }
}
