//
//  ContentView.swift
//  Harvie
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let refreshInvoices = Notification.Name("RefreshInvoices")
    static let searchInvoices = Notification.Name("SearchInvoices")
    static let insertTemplateVariable = Notification.Name("InsertTemplateVariable")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InvoicesViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isSearching = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            InvoicesListView(viewModel: viewModel, columnVisibility: columnVisibility)
        } detail: {
            DetailContentView(viewModel: viewModel)
        }
        .searchable(text: $viewModel.searchText, isPresented: $isSearching, placement: .sidebar, prompt: Strings.InvoicesList.filterPrompt)
        .onReceive(NotificationCenter.default.publisher(for: .searchInvoices)) { _ in
            isSearching = true
        }
        .overlay { ExportOverlayView(viewModel: viewModel) }
        .overlay { MoneyRainOverlay() }
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
                onRefresh: { viewModel.refreshInvoices(ids: [invoice.id]) },
                onStateChanged: { id, newState in
                    if newState == .paid {
                        viewModel.refreshCurrentFilter()
                    } else {
                        viewModel.switchFilterAndSelect(invoiceId: id, to: newState)
                    }
                }
            )
            .id(invoice.id)
        } else {
            ContentUnavailableView(
                Strings.InvoiceDetail.selectAnInvoice,
                systemImage: "doc.text",
                description: Text(Strings.InvoiceDetail.selectAnInvoiceDescription)
            )
        }
    }
}

#Preview {
    ContentView()
}
