//
//  ContentView.swift
//  Harvie
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let refreshInvoices = Notification.Name("RefreshInvoices")
    static let refreshEstimates = Notification.Name("RefreshEstimates")
    static let searchInvoices = Notification.Name("SearchInvoices")
    static let insertTemplateVariable = Notification.Name("InsertTemplateVariable")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var invoicesVM = InvoicesViewModel()
    @State private var estimatesVM = EstimatesViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isSearching = false
    @SceneStorage("documentSource") private var sourceRaw: String = DocumentSource.invoices.rawValue

    private var source: Binding<DocumentSource> {
        Binding(
            get: { DocumentSource(rawValue: sourceRaw) ?? .invoices },
            set: { sourceRaw = $0.rawValue }
        )
    }

    private var estimatesEnabled: Bool { FeatureFlags.estimates }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        .searchable(text: searchTextBinding, isPresented: $isSearching, placement: .sidebar, prompt: searchPrompt)
        .onReceive(NotificationCenter.default.publisher(for: .searchInvoices)) { _ in
            isSearching = true
        }
        .overlay { ExportOverlayView(invoicesVM: invoicesVM, estimatesVM: estimatesVM, source: source.wrappedValue) }
        .overlay { MoneyRainOverlay() }
        .task {
            invoicesVM.modelContext = modelContext
            await invoicesVM.loadSavedState()
            invoicesVM.loadInvoices()

            if estimatesEnabled {
                estimatesVM.modelContext = modelContext
                await estimatesVM.loadSavedState()
                estimatesVM.loadEstimates()
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            if estimatesEnabled {
                Picker("", selection: source) {
                    ForEach(DocumentSource.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            switch source.wrappedValue {
            case .invoices:
                InvoicesListView(viewModel: invoicesVM, columnVisibility: columnVisibility)
            case .estimates:
                EstimatesListView(viewModel: estimatesVM, columnVisibility: columnVisibility)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch source.wrappedValue {
        case .invoices:
            InvoicesDetailContentView(viewModel: invoicesVM)
        case .estimates:
            EstimatesDetailContentView(viewModel: estimatesVM)
        }
    }

    private var searchTextBinding: Binding<String> {
        switch source.wrappedValue {
        case .invoices:
            return Binding(get: { invoicesVM.searchText }, set: { invoicesVM.searchText = $0 })
        case .estimates:
            return Binding(get: { estimatesVM.searchText }, set: { estimatesVM.searchText = $0 })
        }
    }

    private var searchPrompt: String {
        switch source.wrappedValue {
        case .invoices: Strings.InvoicesList.filterPrompt
        case .estimates: Strings.EstimatesList.filterPrompt
        }
    }
}

private struct ExportOverlayView: View {
    var invoicesVM: InvoicesViewModel
    var estimatesVM: EstimatesViewModel
    var source: DocumentSource

    var body: some View {
        switch source {
        case .invoices:
            if invoicesVM.isExporting {
                ExportProgressOverlay(
                    progress: invoicesVM.exportProgress,
                    message: invoicesVM.exportProgressMessage
                )
            }
        case .estimates:
            if estimatesVM.isExporting {
                EstimateExportProgressOverlay(
                    progress: estimatesVM.exportProgress,
                    message: estimatesVM.exportProgressMessage
                )
            }
        }
    }
}

private struct InvoicesDetailContentView: View {
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

private struct EstimatesDetailContentView: View {
    @Bindable var viewModel: EstimatesViewModel

    var body: some View {
        if let estimate = viewModel.selectedEstimate {
            EstimateDetailView(
                estimate: estimate,
                creditorInfo: viewModel.creditorInfo,
                appSettings: viewModel.appSettings,
                onRefresh: { viewModel.refreshEstimates(ids: [estimate.id]) },
                onStateChanged: { id, newState in
                    viewModel.switchFilterAndSelect(estimateId: id, to: newState)
                }
            )
            .id(estimate.id)
        } else {
            ContentUnavailableView(
                Strings.EstimateDetail.selectAnEstimate,
                systemImage: "doc.richtext",
                description: Text(Strings.EstimateDetail.selectAnEstimateDescription)
            )
        }
    }
}

#Preview {
    ContentView()
}
