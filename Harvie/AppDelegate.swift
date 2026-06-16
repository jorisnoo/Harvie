//
//  AppDelegate.swift
//  Harvie
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
        #if DEBUG
        return
        #endif
        updater.check(success: { [updater] in promptInstallIfDownloaded(updater: updater) })
    }

    func checkForUpdates() {
        updater.check(
            success: { [updater] in promptInstallIfDownloaded(updater: updater) },
            fail: { error in
                Task { @MainActor in
                    let alert = NSAlert()
                    if let updateError = error as? AppUpdater.Error, case .noValidUpdate = updateError {
                        alert.messageText = "No Updates Available"
                        alert.informativeText = "You're running the latest version of Harvie."
                        alert.alertStyle = .informational
                    } else {
                        alert.messageText = "Update Check Failed"
                        alert.informativeText = "Could not check for updates. Please try again later."
                        alert.alertStyle = .warning
                    }
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        )
    }
    #endif
}

#if !APP_STORE
@Sendable private nonisolated func promptInstallIfDownloaded(updater: AppUpdater) {
    Task { @MainActor in
        guard case .downloaded(let release, _, let bundle) = updater.state else { return }

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Version \(release.tagName) is ready to install."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

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
#endif
