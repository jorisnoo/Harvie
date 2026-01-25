//
//  HarvestQRBillApp.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData

@main
struct HarvestQRBillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.showSettings) var showSettings
    @FocusedValue(\.refreshAction) var refreshAction

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Analytics.appOpened()
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
                Button("Check for Updates...") {
                    appDelegate.checkForUpdates()
                }
            }
            #endif
        }
        .modelContainer(for: CachedInvoice.self)
    }
}
