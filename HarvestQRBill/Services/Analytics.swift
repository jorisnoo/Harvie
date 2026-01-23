//
//  Analytics.swift
//  HarvestQRBill
//

import AviaryInsights
import Foundation

enum Analytics {
    private static var isEnabled: Bool {
        Bundle.main.infoDictionary?["AnalyticsEnabled"] as? Bool ?? false
    }

    private static var serverURL: URL {
        let urlString = Bundle.main.infoDictionary?["AnalyticsServerURL"] as? String
            ?? "https://plausible.io"
        return URL(string: urlString)!
    }

    private static let plausible: Plausible? = {
        guard isEnabled else { return nil }
        return Plausible(
            defaultDomain: "harvestqrbill.app",
            serverURL: serverURL
        )
    }()

    static func track(_ name: String, path: String = "/", props: [String: String]? = nil) {
        guard let plausible else { return }
        let event = Event(
            url: "app://harvestqrbill\(path)",
            name: name,
            props: props
        )
        plausible.postEvent(event)
    }

    static func appOpened() {
        track("App Open")
    }

    static func pdfExported(count: Int = 1) {
        track("PDF Export", props: ["count": "\(count)"])
    }
}
