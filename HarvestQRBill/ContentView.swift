//
//  ContentView.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData

private struct RefreshActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var refresh: (() -> Void)? {
        get { self[RefreshActionKey.self] }
        set { self[RefreshActionKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InvoicesViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            InvoicesListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if viewModel.selectedInvoiceIDs.count > 1 {
                MultiSelectionView(viewModel: viewModel)
            } else if let invoice = viewModel.selectedInvoice {
                InvoiceDetailView(
                    invoice: invoice,
                    creditorInfo: viewModel.creditorInfo,
                    appSettings: viewModel.appSettings,
                    onRefresh: { viewModel.refreshInvoices(ids: [invoice.id]) }
                )
            } else {
                ContentUnavailableView(
                    "Select an Invoice",
                    systemImage: "doc.text",
                    description: Text("Choose an invoice from the list to view details and generate a QR bill.")
                )
            }
        }
        .focusedSceneValue(\.refresh) { viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { _ in
            Task {
                await viewModel.reloadSettings()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SettingsViewModel.settingsSavedNotification)) { notification in
            Task {
                await viewModel.reloadSettings()
            }
            if notification.userInfo?["needsAPIRefresh"] as? Bool == true {
                viewModel.loadInvoices()
            }
        }
        .overlay {
            if viewModel.isExporting {
                ExportProgressOverlay(
                    progress: viewModel.exportProgress,
                    message: viewModel.exportProgressMessage
                )
            }
        }
        .task {
            viewModel.modelContext = modelContext
            await viewModel.loadSavedState()
            viewModel.loadInvoices()
        }
    }
}

#Preview {
    ContentView()
}
