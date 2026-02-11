//
//  HarvestQRBillApp.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData
#if !APP_STORE
import AppUpdater
#endif

@main
struct HarvestQRBillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.refresh) private var refresh

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Analytics.initialize()
                    Analytics.appLaunched()
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    refresh?()
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            #if !APP_STORE
            CommandGroup(after: .appInfo) {
                UpdateMenuCommands(updater: appDelegate.updater, checkForUpdates: appDelegate.checkForUpdates)
            }
            #endif
        }
        .modelContainer(for: CachedInvoice.self)

        Settings {
            SettingsView()
        }
    }
}

#if !APP_STORE
struct UpdateMenuCommands: View {
    @ObservedObject var updater: AppUpdater
    var checkForUpdates: () -> Void

    var body: some View {
        Button("Check for Updates...") {
            checkForUpdates()
        }

        if case .downloaded(_, _, let bundle) = updater.state {
            Button("Restart and Update") {
                Task {
                    try await updater.installThrowing(bundle)
                }
            }
        }
    }
}
#endif
