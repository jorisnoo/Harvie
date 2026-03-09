//
//  InvoicesListView.swift
//  HarvestQRBill
//

import SwiftUI

struct InvoicesListView: View {
    @Bindable var viewModel: InvoicesViewModel
    var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.openSettings) private var openSettings

    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(Strings.InvoicesList.creditorWarning)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Button(Strings.Common.settings) {
                openSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
    }

    @ViewBuilder
    private var invoicesList: some View {
        List(selection: $viewModel.selectedInvoiceIDs) {
            ForEach(viewModel.sortedInvoices) { invoice in
                InvoiceRowView(
                    invoice: invoice,
                    sortOption: viewModel.sortOption
                )
                .tag(invoice.id)
                // TODO: Re-enable drag-and-drop export once fully working
                // .onDrag { viewModel.createDragProvider(for: invoice) }
            }
        }
        .onKeyPress(.escape) {
            guard !viewModel.selectedInvoiceIDs.isEmpty else { return .ignored }
            viewModel.selectedInvoiceIDs.removeAll()
            return .handled
        }
        .contextMenu(forSelectionType: Int.self) { selectedIDs in
            if !selectedIDs.isEmpty {
                Button {
                    Task {
                        await viewModel.exportSelectedInvoices(withQRBill: true)
                    }
                } label: {
                    Label(Strings.InvoicesList.exportWithQRBill, systemImage: "square.and.arrow.down")
                }
                .disabled(!viewModel.canExportWithQRBill)

                Button {
                    Task {
                        await viewModel.exportSelectedInvoices(withQRBill: false)
                    }
                } label: {
                    Label(Strings.InvoicesList.exportWithoutQRBill, systemImage: "doc.text")
                }
            }
        } primaryAction: { selectedIDs in
            if let firstID = selectedIDs.first {
                viewModel.selectedInvoiceIDs = [firstID]
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !viewModel.canExportWithQRBill {
                warningBanner
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarStatusBar(invoices: viewModel.sortedInvoices)
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.invoices.isEmpty {
                ProgressView(Strings.InvoicesList.loading)
            } else if let error = viewModel.error {
                if !viewModel.hasValidCredentials {
                    ContentUnavailableView {
                        Label(Strings.InvoicesList.setupRequired, systemImage: "gear")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(Strings.InvoicesList.openSettings) {
                            openSettings()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(Strings.Common.retry) {
                            viewModel.loadInvoices()
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label(Strings.Common.error, systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(Strings.Common.retry) {
                            viewModel.loadInvoices()
                        }
                    }
                }
            } else if viewModel.invoices.isEmpty {
                ContentUnavailableView {
                    Label(Strings.InvoicesList.noInvoices, systemImage: "doc.text")
                } description: {
                    Text(Strings.InvoicesList.noInvoicesForState(viewModel.stateFilter?.rawValue ?? ""))
                } actions: {
                    Button(Strings.Common.refresh) {
                        viewModel.refresh()
                    }
                }
            } else {
                invoicesList
            }
        }
        .navigationTitle(Strings.InvoicesList.title)
        .navigationSubtitle(viewModel.isRefreshing ? Strings.InvoicesList.updating : "")
        .modifier(InvoicesAlertsModifier(viewModel: viewModel))
        .toolbar {
            InvoicesToolbarContent(viewModel: viewModel, columnVisibility: columnVisibility)
        }
        .modifier(InvoicesOnChangeModifier(viewModel: viewModel))
    }
}

// MARK: - Toolbar (isolated observation scope)

private struct InvoicesToolbarContent: ToolbarContent {
    @Bindable var viewModel: InvoicesViewModel
    var columnVisibility: NavigationSplitViewVisibility = .all

    private var sortFilterMenuLabel: String {
        if let period = viewModel.selectedPeriod {
            return viewModel.formatPeriod(period)
        }
        return Strings.InvoicesList.sortAndFilter
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if columnVisibility != .detailOnly {
                Menu {
                    Section(Strings.InvoicesList.sortBy) {
                        ForEach(InvoiceSortOption.allCases, id: \.self) { option in
                            Button {
                                if viewModel.sortOption == option {
                                    viewModel.sortDirection.toggle()
                                } else {
                                    viewModel.sortOption = option
                                    viewModel.sortDirection = .descending
                                }
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    if viewModel.sortOption == option {
                                        Image(systemName: viewModel.sortDirection == .ascending ? "chevron.up" : "chevron.down")
                                    }
                                }
                            }
                            .disabled(!viewModel.validSortOptions.contains(option))
                        }
                    }

                    Divider()

                    Section(Strings.InvoicesList.filterPeriod) {
                        ForEach(DateFilterPeriod.allCases, id: \.self) { period in
                            Button {
                                if viewModel.filterPeriod != period {
                                    viewModel.filterPeriod = period
                                    viewModel.selectedPeriod = nil
                                }
                            } label: {
                                HStack {
                                    Text(period.rawValue)
                                    if viewModel.filterPeriod == period {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Section(Strings.InvoicesList.filterByPeriod(viewModel.filterPeriod.rawValue)) {
                        Button {
                            viewModel.selectedPeriod = nil
                        } label: {
                            HStack {
                                Text(Strings.InvoicesList.all)
                                if viewModel.selectedPeriod == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        ForEach(viewModel.availablePeriods, id: \.self) { period in
                            Button {
                                viewModel.selectedPeriod = period
                            } label: {
                                HStack {
                                    Text(viewModel.formatPeriod(period))
                                    if let selected = viewModel.selectedPeriod, selected == period {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label(sortFilterMenuLabel, systemImage: "line.3.horizontal.decrease.circle")
                }
                .focusable(false)

                Picker("Filter", selection: $viewModel.stateFilter) {
                    Text(Strings.InvoicesList.stateOpen).tag(InvoiceState?.some(.open))
                    Text(Strings.InvoicesList.statePaid).tag(InvoiceState?.some(.paid))
                    Text(Strings.InvoicesList.stateDraft).tag(InvoiceState?.some(.draft))
                    Text(Strings.InvoicesList.stateClosed).tag(InvoiceState?.some(.closed))
                    Divider()
                    Text(Strings.InvoicesList.all).tag(InvoiceState?.none)
                }
                .pickerStyle(.menu)
            }
        }
    }
}

// MARK: - Alerts (isolated observation scope)

private struct InvoicesAlertsModifier: ViewModifier {
    @Bindable var viewModel: InvoicesViewModel

    func body(content: Content) -> some View {
        content
            .alert(Strings.Alerts.exportError, isPresented: .init(
                get: { viewModel.exportError != nil },
                set: { if !$0 { viewModel.exportError = nil } }
            )) {
                Button(Strings.Common.ok) { viewModel.exportError = nil }
            } message: {
                Text(viewModel.exportError ?? "")
            }
            .alert(Strings.Alerts.exportComplete, isPresented: $viewModel.showExportSuccess) {
                Button(Strings.Common.ok) { }
            } message: {
                Text(Strings.Alerts.exportedCount(viewModel.exportedCount))
            }
            .alert(Strings.Alerts.updateError, isPresented: .init(
                get: { viewModel.updateError != nil },
                set: { if !$0 { viewModel.updateError = nil } }
            )) {
                Button(Strings.Common.ok) { viewModel.updateError = nil }
            } message: {
                Text(viewModel.updateError ?? "")
            }
            .alert(Strings.Alerts.updateComplete, isPresented: $viewModel.showUpdateSuccess) {
                Button(Strings.Common.ok) { }
            } message: {
                Text(Strings.Alerts.updatedCount(viewModel.updatedCount))
            }
    }
}

// MARK: - onChange handlers (isolated observation scope)

private struct InvoicesOnChangeModifier: ViewModifier {
    var viewModel: InvoicesViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.stateFilter) {
                guard viewModel.isInitialized else { return }

                if !viewModel.validSortOptions.contains(viewModel.sortOption) {
                    viewModel.sortOption = .issueDate
                }

                viewModel.deselectAll()
                viewModel.loadInvoices()
                viewModel.debouncedSaveState()
            }
            .onChange(of: viewModel.sortOption) {
                guard viewModel.isInitialized else { return }
                viewModel.clearInvalidSelections()
                viewModel.debouncedSaveState()
            }
            .onChange(of: viewModel.sortDirection) {
                guard viewModel.isInitialized else { return }
                viewModel.debouncedSaveState()
            }
            .onChange(of: viewModel.filterPeriod) {
                guard viewModel.isInitialized else { return }
                viewModel.clearInvalidSelections()
                viewModel.debouncedSaveState()
            }
            .onChange(of: viewModel.selectedPeriod) {
                guard viewModel.isInitialized else { return }
                viewModel.clearInvalidSelections()
                viewModel.debouncedSaveState()
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshInvoices)) { _ in
                viewModel.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: SettingsViewModel.settingsSavedNotification)) { notification in
                Task { await viewModel.reloadSettings() }
                if notification.userInfo?["needsAPIRefresh"] as? Bool == true {
                    viewModel.loadInvoices()
                }
            }
    }
}

struct ExportProgressOverlay: View {
    let progress: Double
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: progress) {
                    Text(Strings.InvoicesList.exportingInvoices)
                        .font(.headline)
                } currentValueLabel: {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
                .frame(width: 250)
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct SidebarStatusBar: View {
    let invoices: [Invoice]

    private var totalByCurrency: [(currency: String, total: Decimal)] {
        Dictionary(grouping: invoices, by: \.currency)
            .map { (currency: $0.key, total: $0.value.reduce(0) { $0 + $1.displayAmount }) }
            .sorted { $0.currency < $1.currency }
    }

    var body: some View {
        if !invoices.isEmpty {
            HStack {
                Text(Strings.InvoicesList.invoiceCount(invoices.count))
                Spacer()
                Text(totalByCurrency.map { CurrencyFormatter.format($0.total, currency: $0.currency) }.joined(separator: " · "))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
}

struct InvoiceRowView: View {
    let invoice: Invoice
    var sortOption: InvoiceSortOption = .issueDate

    private var formattedAmount: String {
        CurrencyFormatter.format(invoice.displayAmount, currency: invoice.currency)
    }

    private var dateValue: Date {
        switch sortOption {
        case .issueDate: invoice.issueDate
        case .dueDate: invoice.dueDate
        case .paidDate: invoice.effectivePaidDate ?? invoice.issueDate
        }
    }

    private var formattedDate: String {
        dateValue.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.number)
                    .font(.headline)

                Text(invoice.client.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .fixedSize()
        }
        .padding(.vertical, 4)
    }
}

struct StateIndicator: View {
    let state: InvoiceState

    private var color: Color {
        switch state {
        case .draft: .gray
        case .open: .orange
        case .paid: .green
        case .closed: .blue
        }
    }

    var body: some View {
        Text(state.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        InvoicesListView(viewModel: InvoicesViewModel())
    }
}
