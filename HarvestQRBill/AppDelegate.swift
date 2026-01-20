//
//  AppDelegate.swift
//  HarvestQRBill
//

import AppKit
import AppUpdater
import PromiseKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let updater = AppUpdater(owner: "jorisnoo", repo: "HarvestQRBill")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppUpdater checks for updates daily automatically
    }

    @objc func checkForUpdates() {
        updater.check().catch(policy: .allErrors) { error in
            if error.isCancelled {
                let alert = NSAlert()
                alert.messageText = "No Updates Available"
                alert.informativeText = "You're running the latest version of HarvestQRBill."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}
