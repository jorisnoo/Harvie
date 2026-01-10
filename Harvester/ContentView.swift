//
//  ContentView.swift
//  Harvester
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = InvoicesViewModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            InvoicesListView(viewModel: viewModel)
                .frame(minWidth: 300)
        } detail: {
            if let invoice = viewModel.selectedInvoice {
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
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            await viewModel.loadInvoices()
        }
    }
}

#Preview {
    ContentView()
}
