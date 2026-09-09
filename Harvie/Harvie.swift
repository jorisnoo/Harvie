//
//  HarvieApp.swift
//  Harvie
//

import SwiftUI
import SwiftData
#if !APP_STORE
import AppUpdater
#endif

@main
struct HarvieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let modelContainer: ModelContainer

    init() {
        if !AppEnvironment.isRunningTests { LegacyMigration.migrateIfNeeded() }

        do {
            let schema = Schema([CachedInvoice.self, CachedEstimate.self, InvoiceTemplate.self, ClientOverride.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: AppEnvironment.isRunningTests)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        Window(Strings.App.title, id: "main") {
            if AppEnvironment.isRunningTests {
                Color.clear
            } else {
                ContentView()
                    .onAppear {
                        Analytics.initialize()
                        Analytics.appLaunched()
                    }
                    .task {
                        if FeatureFlags.customPDFTemplates {
                            await MainActor.run {
                                TemplateSeeder.seedIfNeeded(context: modelContainer.mainContext)
                            }
                        }
                    }
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .saveItem) {
                ExportMenuButton()
            }

            CommandGroup(after: .toolbar) {
                Button(Strings.Common.refresh) {
                    NotificationCenter.default.post(name: .refreshInvoices, object: nil)
                    NotificationCenter.default.post(name: .refreshEstimates, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button(Strings.Common.find) {
                    NotificationCenter.default.post(name: .searchInvoices, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            #if !APP_STORE
            CommandGroup(after: .appInfo) {
                AppUpdateMenu(controller: appDelegate.updates)
            }
            #endif
        }
        .modelContainer(modelContainer)

        Window(Strings.DataExport.windowTitle, id: "export") {
            if AppEnvironment.isRunningTests { Color.clear } else { ExportView() }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 640)

        Settings {
            if AppEnvironment.isRunningTests {
                Color.clear
            } else {
                SettingsView().modelContainer(modelContainer)
            }
        }
    }
}

private struct ExportMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(Strings.DataExport.menuItem) {
            openWindow(id: "export")
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
    }
}
