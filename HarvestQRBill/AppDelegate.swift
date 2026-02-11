//
//  AppDelegate.swift
//  HarvestQRBill
//

import AppKit
#if !APP_STORE
import AppUpdater
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    #if !APP_STORE
    let updater = AppUpdater(
        owner: Bundle.main.infoDictionary?["GHRepositoryOwner"] as! String,
        repo: Bundle.main.infoDictionary?["GHRepositoryName"] as! String
    )

    func checkForUpdates() {
        updater.check(
            success: {
                // Update found and downloaded - AppUpdater handles the flow
            },
            fail: { error in
                Task { @MainActor in
                    if let updateError = error as? AppUpdater.Error, case .noValidUpdate = updateError {
                        let alert = NSAlert()
                        alert.messageText = "No Updates Available"
                        alert.informativeText = "You're running the latest version of HarvestQRBill."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Update Check Failed"
                        alert.informativeText = "Could not check for updates. Please try again later."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        )
    }
    #endif
}
