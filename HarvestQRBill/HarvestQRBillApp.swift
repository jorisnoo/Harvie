//
//  HarvestQRBillApp.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData

@main
struct HarvestQRBillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    appDelegate.checkForUpdates()
                }
            }
        }
        .modelContainer(for: CachedInvoice.self)
    }
}
