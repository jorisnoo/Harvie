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
    static let newInvoice = Notification.Name("NewInvoice")
    static let insertTemplateVariable = Notification.Name("InsertTemplateVariable")
}

struct ContentView: View {
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

    // Keep modifiers off the NavigationSplitView (see AGENTS.md): loading, overlays and
    // notification handling live in sibling views so sidebar animation doesn't re-evaluate them.
    var body: some View {
        ZStack {
            DocumentsLifecycleView(invoicesVM: invoicesVM, estimatesVM: estimatesVM, estimatesEnabled: estimatesEnabled)

            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar
                    .navigationSplitViewColumnWidth(min: 300, ideal: 360)
            } detail: {
                detail
                    .modifier(DetailSaveErrorAlert())
            }

            ExportOverlayView(invoicesVM: invoicesVM, estimatesVM: estimatesVM, source: source.wrappedValue)
            MoneyRainOverlay()
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        Group {
            switch source.wrappedValue {
            case .invoices:
                InvoicesListView(viewModel: invoicesVM)
            case .estimates:
                EstimatesListView(viewModel: estimatesVM)
            }
        }
        .searchable(text: searchTextBinding, isPresented: $isSearching, placement: .sidebar, prompt: searchPrompt)
        .onReceive(NotificationCenter.default.publisher(for: .searchInvoices)) { _ in
            isSearching = true
        }
        .toolbar {
            if columnVisibility != .detailOnly {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 6) {
                        if let activeFilterLabel {
                            Text(activeFilterLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize()
                        }

                        sortFilterMenu
                    }
                }

                if source.wrappedValue == .invoices {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            invoicesVM.showNewInvoiceSheet = true
                        } label: {
                            Label(Strings.NewInvoice.title, systemImage: "plus")
                        }
                        .disabled(!invoicesVM.hasValidCredentials)
                        .help(Strings.NewInvoice.title)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newInvoice)) { _ in
            guard invoicesVM.hasValidCredentials else { return }
            source.wrappedValue = .invoices
            invoicesVM.showNewInvoiceSheet = true
        }
    }

    private var sortFilterMenu: some View {
        Menu {
            if estimatesEnabled {
                Picker(Strings.DocumentSource.document, selection: source) {
                    ForEach(DocumentSource.allCases) { documentSource in
                        Text(documentSource.displayName).tag(documentSource)
                    }
                }
                .pickerStyle(.inline)

                Divider()
            }

            if source.wrappedValue == .invoices {
                sortFilterMenuItems
            }
        } label: {
            Label(Strings.InvoicesList.sortAndFilter, systemImage: "line.3.horizontal.decrease.circle")
        }
        .focusable(false)
    }

    private var activeFilterLabel: String? {
        if source.wrappedValue == .invoices, let period = invoicesVM.selectedPeriod {
            return invoicesVM.filterPeriod.displayLabel(for: period)
        }
        return nil
    }

    @ViewBuilder
    private var sortFilterMenuItems: some View {
        Section(Strings.InvoicesList.sortBy) {
            ForEach(InvoiceSortOption.allCases, id: \.self) { option in
                Button {
                    if invoicesVM.sortOption == option {
                        invoicesVM.sortDirection.toggle()
                    } else {
                        invoicesVM.sortOption = option
                        invoicesVM.sortDirection = .descending
                    }
                } label: {
                    HStack {
                        Text(option.displayName)
                        if invoicesVM.sortOption == option {
                            Image(systemName: invoicesVM.sortDirection == .ascending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
                .disabled(!invoicesVM.validSortOptions.contains(option))
            }
        }

        Section(Strings.InvoicesList.filterPeriod) {
            ForEach(DateFilterPeriod.allCases, id: \.self) { period in
                Button {
                    if invoicesVM.filterPeriod != period {
                        invoicesVM.filterPeriod = period
                        invoicesVM.selectedPeriod = nil
                    }
                } label: {
                    HStack {
                        Text(period.displayName)
                        if invoicesVM.filterPeriod == period {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Section(Strings.InvoicesList.filterByPeriod(invoicesVM.filterPeriod.displayName)) {
            Button {
                invoicesVM.selectedPeriod = nil
            } label: {
                HStack {
                    Text(Strings.InvoicesList.all)
                    if invoicesVM.selectedPeriod == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(invoicesVM.availablePeriods, id: \.self) { period in
                Button {
                    invoicesVM.selectedPeriod = period
                } label: {
                    HStack {
                        Text(invoicesVM.filterPeriod.displayLabel(for: period))
                        if invoicesVM.selectedPeriod == period {
                            Image(systemName: "checkmark")
                        }
                    }
                }
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

/// Zero-size helper that loads both document lists and applies saved settings to them.
/// Lives outside the list views so a hidden list still picks up account changes.
private struct DocumentsLifecycleView: View {
    @Environment(\.modelContext) private var modelContext
    let invoicesVM: InvoicesViewModel
    let estimatesVM: EstimatesViewModel
    let estimatesEnabled: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
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
            .onReceive(NotificationCenter.default.publisher(for: SettingsViewModel.settingsSavedNotification)) { notification in
                let needsAPIRefresh = notification.userInfo?["needsAPIRefresh"] as? Bool == true
                Task {
                    // Reload settings first so the refetch sees the new demo-mode flag.
                    await invoicesVM.reloadSettings()
                    if needsAPIRefresh { invoicesVM.loadInvoices() }

                    guard estimatesEnabled else { return }
                    await estimatesVM.reloadSettings()
                    if needsAPIRefresh { estimatesVM.loadEstimates() }
                }
            }
    }
}

/// Reports inline-edit saves that failed after their detail view was already gone.
private struct DetailSaveErrorAlert: ViewModifier {
    @State private var message: String?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .detailSaveFailed)) { notification in
                message = notification.userInfo?["message"] as? String
            }
            .alert(Strings.Common.error, isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button(Strings.Common.ok) { message = nil }
            } message: {
                Text(message ?? "")
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
                    // Keeps the invoice visible and selected (so the detail view and its
                    // success alert stay up) and refreshes just that invoice.
                    viewModel.switchFilterAndSelect(invoiceId: id, to: newState)
                },
                onDelete: { viewModel.showDeleteSheet = true }
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
