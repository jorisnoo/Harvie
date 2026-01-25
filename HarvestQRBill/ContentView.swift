//
//  ContentView.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData

// Focus keys for menu bar commands
struct ShowSettingsKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct RefreshActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var showSettings: Binding<Bool>? {
        get { self[ShowSettingsKey.self] }
        set { self[ShowSettingsKey.self] = newValue }
    }

    var refreshAction: (() -> Void)? {
        get { self[RefreshActionKey.self] }
        set { self[RefreshActionKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InvoicesViewModel()
    @State private var showingSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            InvoicesListView(viewModel: viewModel, showingSettings: $showingSettings, sidebarVisible: columnVisibility != .detailOnly)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if viewModel.selectedInvoiceIDs.count > 1 {
                MultiSelectionView(viewModel: viewModel)
            } else if let invoice = viewModel.selectedInvoice {
                InvoiceDetailView(invoice: invoice)
            } else {
                ContentUnavailableView(
                    "Select an Invoice",
                    systemImage: "doc.text",
                    description: Text("Choose an invoice from the list to view details and generate a QR bill.")
                )
            }
        }
        .focusedValue(\.showSettings, $showingSettings)
        .focusedValue(\.refreshAction) { viewModel.refresh() }
        .sheet(isPresented: $showingSettings, onDismiss: {
            Task {
                await viewModel.reloadCreditorInfo()
            }
        }) {
            NavigationStack {
                SettingsView()
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
