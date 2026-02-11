//
//  ContentView.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InvoicesViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            InvoicesListView(viewModel: viewModel, sidebarVisible: columnVisibility != .detailOnly)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if viewModel.selectedInvoiceIDs.count > 1 {
                MultiSelectionView(viewModel: viewModel)
            } else if let invoice = viewModel.selectedInvoice {
                InvoiceDetailView(invoice: invoice, onRefresh: { viewModel.refreshInvoices(ids: [invoice.id]) })
            } else {
                ContentUnavailableView(
                    "Select an Invoice",
                    systemImage: "doc.text",
                    description: Text("Choose an invoice from the list to view details and generate a QR bill.")
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuRefreshTriggered)) { _ in
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { _ in
            Task {
                await viewModel.reloadCreditorInfo()
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
