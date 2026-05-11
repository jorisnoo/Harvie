//
//  InvoicesListView.swift
//  Harvie
//

import SwiftUI

struct InvoicesListView: View {
    @Bindable var viewModel: InvoicesViewModel
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
        .modifier(InvoicesOnChangeModifier(viewModel: viewModel))
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

    private var formattedTotal: String {
        totalByCurrency.map { CurrencyFormatter.format($0.total, currency: $0.currency) }.joined(separator: " · ")
    }

    var body: some View {
        if !invoices.isEmpty {
            HStack {
                Text(Strings.InvoicesList.invoiceCount(invoices.count))
                    .contentTransition(.numericText())
                Spacer()
                Text(formattedTotal)
                    .contentTransition(.numericText())
            }
            .animation(.default, value: formattedTotal)
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

    private func prefixedDate(_ formatted: String) -> String {
        switch sortOption {
        case .issueDate: Strings.InvoiceDetail.issued(formatted)
        case .dueDate: Strings.InvoiceDetail.due(formatted)
        case .paidDate: Strings.InvoiceDetail.paid(formatted)
        }
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
                    .contentTransition(.numericText())
                    .animation(.default, value: invoice.displayAmount)
                    .fixedSize()

                ViewThatFits(in: .horizontal) {
                    Text(prefixedDate(dateValue.formatted(date: .abbreviated, time: .omitted)))
                    Text(prefixedDate(dateValue.formatted(date: .numeric, time: .omitted)))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
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
