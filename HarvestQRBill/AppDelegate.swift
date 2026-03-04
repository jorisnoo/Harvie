//
//  AppDelegate.swift
//  HarvestQRBill
//

import AppKit
#if !APP_STORE
import AppUpdater
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    #if !APP_STORE
    let updater = AppUpdater(
        owner: Bundle.main.infoDictionary?["GHRepositoryOwner"] as! String,
        repo: Bundle.main.infoDictionary?["GHRepositoryName"] as! String
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        updater.check(
            success: { [updater] in
                Task { @MainActor in
                    guard case .downloaded(let release, _, let bundle) = updater.state else { return }

                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(release.tagName) is ready to install."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Restart Now")
                    alert.addButton(withTitle: "Later")

                    if alert.runModal() == .alertFirstButtonReturn {
                        do {
                            try await updater.installThrowing(bundle)
                        } catch {
                            let errorAlert = NSAlert()
                            errorAlert.messageText = "Update Failed"
                            errorAlert.informativeText = error.localizedDescription
                            errorAlert.alertStyle = .warning
                            errorAlert.addButton(withTitle: "OK")
                            errorAlert.runModal()
                        }
                    }
                }
            }
        )
    }

    func checkForUpdates() {
        updater.check(
            success: { [updater] in
                Task { @MainActor in
                    guard case .downloaded(let release, _, let bundle) = updater.state else { return }

                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(release.tagName) is ready to install."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Restart Now")
                    alert.addButton(withTitle: "Later")

                    if alert.runModal() == .alertFirstButtonReturn {
                        do {
                            try await updater.installThrowing(bundle)
                        } catch {
                            let errorAlert = NSAlert()
                            errorAlert.messageText = "Update Failed"
                            errorAlert.informativeText = error.localizedDescription
                            errorAlert.alertStyle = .warning
                            errorAlert.addButton(withTitle: "OK")
                            errorAlert.runModal()
                        }
                    }
                }
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
