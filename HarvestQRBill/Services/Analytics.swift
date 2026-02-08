//
//  Analytics.swift
//  HarvestQRBill
//

import Aptabase
import Foundation

enum Analytics {
    private static var isInitialized = false

    private static var distribution: String {
        #if APP_STORE
        "app_store"
        #else
        "direct"
        #endif
    }

    static func initialize() {
        #if DEBUG
        return
        #else
        guard let appKey = Bundle.main.infoDictionary?["AptabaseAppKey"] as? String,
              !appKey.isEmpty
        else { return }

        Aptabase.shared.initialize(appKey: appKey)
        isInitialized = true
        #endif
    }

    private static func track(_ event: String, props: [String: Any] = [:]) {
        #if DEBUG
        return
        #else
        guard isInitialized else { return }

        var allProps = props
        allProps["distribution"] = distribution
        Aptabase.shared.trackEvent(event, with: allProps)
        #endif
    }

    static func appLaunched() {
        track("app_launched")
    }

    static func harvestConnected() {
        track("harvest_connected")
    }

    static func settingsSaved() {
        track("settings_saved")
    }

    static func invoicesLoaded(count: Int) {
        track("invoices_loaded", props: ["count": count])
    }

    static func pdfPreviewed() {
        track("pdf_previewed")
    }

    static func pdfExported(method: String) {
        track("pdf_exported", props: ["method": method])
    }

    static func batchExportCompleted(count: Int, withQRBill: Bool) {
        track("batch_export_completed", props: [
            "count": count,
            "with_qr_bill": withQRBill,
        ])
    }
}
