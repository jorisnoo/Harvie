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

    var body: some View {
        NavigationSplitView {
            InvoicesListView(viewModel: viewModel)
                .frame(minWidth: 300)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            viewModel.modelContext = modelContext
            await viewModel.loadInvoices()
        }
    }
}

#Preview {
    ContentView()
}
