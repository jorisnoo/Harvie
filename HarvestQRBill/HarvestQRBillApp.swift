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
    @FocusedValue(\.showSettings) var showSettings
    @FocusedValue(\.refreshAction) var refreshAction

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

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    showSettings?.wrappedValue = true
                }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(showSettings == nil)
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    refreshAction?()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(refreshAction == nil)
            }

            #if !APP_STORE
            CommandGroup(after: .appInfo) {
                UpdateMenuCommands(updater: appDelegate.updater, checkForUpdates: appDelegate.checkForUpdates)
            }
            #endif
        }
        .modelContainer(for: CachedInvoice.self)
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
