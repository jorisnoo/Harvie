//
//  HarvestQRBillApp.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData

@main
struct HarvestQRBillApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .modelContainer(for: CachedInvoice.self)
    }
}
