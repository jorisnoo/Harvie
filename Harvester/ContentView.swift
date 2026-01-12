//
//  ContentView.swift
//  Harvester
//

import SwiftUI
import SwiftData

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
                ContentUnavailableView(
                    "\(viewModel.selectedInvoiceIDs.count) Invoices Selected",
                    systemImage: "doc.on.doc",
                    description: Text("Right-click to export selected invoices.")
                )
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
        .sheet(isPresented: $showingSettings) {
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
            await viewModel.loadInvoices()
        }
    }
}

#Preview {
    ContentView()
}
