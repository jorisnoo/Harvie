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
            InvoicesListView(viewModel: viewModel, sidebarVisible: columnVisibility != .detailOnly)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)

                    Divider()

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .keyboardShortcut(",", modifiers: .command)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
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
