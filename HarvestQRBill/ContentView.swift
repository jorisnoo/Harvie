//
//  ContentView.swift
//  HarvestQRBill
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let refreshInvoices = Notification.Name("RefreshInvoices")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InvoicesViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            InvoicesListView(viewModel: viewModel)
        } detail: {
            DetailContentView(viewModel: viewModel)
        }
        .overlay { ExportOverlayView(viewModel: viewModel) }
        .task {
            viewModel.modelContext = modelContext
            await viewModel.loadSavedState()
            viewModel.loadInvoices()
        }
    }
}

private struct ExportOverlayView: View {
    var viewModel: InvoicesViewModel

    var body: some View {
        if viewModel.isExporting {
            ExportProgressOverlay(
                progress: viewModel.exportProgress,
                message: viewModel.exportProgressMessage
            )
        }
    }
}

private struct DetailContentView: View {
    @Bindable var viewModel: InvoicesViewModel

    var body: some View {
        if viewModel.selectedInvoiceIDs.count > 1 {
            MultiSelectionView(viewModel: viewModel)
        } else if let invoice = viewModel.selectedInvoice {
            InvoiceDetailView(
                invoice: invoice,
                creditorInfo: viewModel.creditorInfo,
                appSettings: viewModel.appSettings,
                onRefresh: { viewModel.refreshInvoices(ids: [invoice.id]) }
            )
            .id(invoice.id)
        } else {
            ContentUnavailableView(
                "Select an Invoice",
                systemImage: "doc.text",
                description: Text("Choose an invoice from the list to view details and generate a QR bill.")
            )
        }
    }
}

#Preview {
    ContentView()
}
