//
//  AppDelegate.swift
//  HarvestQRBill
//

import AppKit
#if !APP_STORE
import AppUpdater
import PromiseKit
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    #if !APP_STORE
    let updater = AppUpdater(owner: "jorisnoo", repo: "HarvestQRBill")
    
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
    #endif
}
