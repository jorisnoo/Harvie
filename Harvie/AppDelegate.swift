import AppKit
#if !APP_STORE
import AppUpdater
#endif

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    #if !APP_STORE
    let updates = AppUpdateController(owner: "jorisnoo", repo: "Harvie")

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }
        updates.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        updates.applicationShouldTerminate(sender)
    }
    #endif
}
