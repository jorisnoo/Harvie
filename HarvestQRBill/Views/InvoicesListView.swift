//
//  InvoicesListView.swift
//  HarvestQRBill
//

import SwiftUI

struct InvoicesListView: View {
    @Bindable var viewModel: InvoicesViewModel
    @Binding var showingSettings: Bool
    var sidebarVisible: Bool = true

    private var sortFilterMenuLabel: String {
        if let period = viewModel.selectedPeriod {
            return viewModel.formatPeriod(period)
        }
        return "Sort & Filter"
    }

    @ViewBuilder
    private var invoicesList: some View {
        List(viewModel.sortedInvoices, selection: $viewModel.selectedInvoiceIDs) { invoice in
            InvoiceRowView(
                invoice: invoice,
                sortOption: viewModel.sortOption
            )
            .tag(invoice.id)
            .simultaneousGesture(
                TapGesture().onEnded {
                    let modifiers = NSApp.currentEvent?.modifierFlags ?? []
                    let hasModifiers = modifiers.contains(.command) || modifiers.contains(.shift)
                    if !hasModifiers {
                        viewModel.selectedInvoiceIDs = [invoice.id]
                    }
                }
            )
        }
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedInvoiceIDs.removeAll()
                }
        }
        .onKeyPress(.escape) {
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
                    Label("Export with QR Bill", systemImage: "square.and.arrow.down")
                }
                .disabled(!viewModel.canExportWithQRBill)

                Button {
                    Task {
                        await viewModel.exportSelectedInvoices(withQRBill: false)
                    }
                } label: {
                    Label("Export without QR Bill", systemImage: "doc.text")
                }
            }
        } primaryAction: { selectedIDs in
            if let firstID = selectedIDs.first {
                viewModel.selectedInvoice = viewModel.invoices.first { $0.id == firstID }
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.invoices.isEmpty {
                ProgressView("Loading invoices...")
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        viewModel.loadInvoices()
                    }
                }
            } else if viewModel.invoices.isEmpty {
                ContentUnavailableView {
                    Label("No Invoices", systemImage: "doc.text")
                } description: {
                    Text("No \(viewModel.stateFilter?.rawValue ?? "") invoices found.")
                } actions: {
                    Button("Refresh") {
                        viewModel.refresh()
                    }
                }
            } else {
                invoicesList
            }
        }
        .navigationTitle("Invoices")
        .navigationSubtitle(viewModel.isRefreshing ? "Updating..." : "")
        .safeAreaInset(edge: .top) {
            if !viewModel.canExportWithQRBill && !viewModel.invoices.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Configure creditor info in Settings to enable QR bill export.")
                        .font(.callout)
                    Spacer()
                    Button("Settings") {
                        showingSettings = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1))
            }
        }
        .alert("Export Error", isPresented: .init(
            get: { viewModel.exportError != nil },
            set: { if !$0 { viewModel.exportError = nil } }
        )) {
            Button("OK") { viewModel.exportError = nil }
        } message: {
            Text(viewModel.exportError ?? "")
        }
        .alert("Export Complete", isPresented: $viewModel.showExportSuccess) {
            Button("OK") { }
        } message: {
            Text("Successfully exported \(viewModel.exportedCount) invoice(s).")
        }
        .alert("Update Error", isPresented: .init(
            get: { viewModel.updateError != nil },
            set: { if !$0 { viewModel.updateError = nil } }
        )) {
            Button("OK") { viewModel.updateError = nil }
        } message: {
            Text(viewModel.updateError ?? "")
        }
        .alert("Update Complete", isPresented: $viewModel.showUpdateSuccess) {
            Button("OK") { }
        } message: {
            Text("Successfully updated \(viewModel.updatedCount) invoice(s).")
        }
        .toolbar {
            if sidebarVisible {
                ToolbarItemGroup(placement: .automatic) {
                    Menu {
                        Section("Sort By") {
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

                        Section("Filter Period") {
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

                        Section("Filter by \(viewModel.filterPeriod.rawValue)") {
                            Button {
                                viewModel.selectedPeriod = nil
                            } label: {
                                HStack {
                                    Text("All")
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

                    Picker("Filter", selection: $viewModel.stateFilter) {
                        Text("Open").tag(InvoiceState?.some(.open))
                        Text("Paid").tag(InvoiceState?.some(.paid))
                        Text("Draft").tag(InvoiceState?.some(.draft))
                        Text("Closed").tag(InvoiceState?.some(.closed))
                        Divider()
                        Text("All").tag(InvoiceState?.none)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .onChange(of: viewModel.stateFilter) {
            if !viewModel.validSortOptions.contains(viewModel.sortOption) {
                viewModel.sortOption = .issueDate
            }

            viewModel.loadInvoices()
            Task {
                await viewModel.saveState()
            }
        }
        .onChange(of: viewModel.sortOption) {
            Task { await viewModel.saveState() }
        }
        .onChange(of: viewModel.sortDirection) {
            Task { await viewModel.saveState() }
        }
        .onChange(of: viewModel.filterPeriod) {
            Task { await viewModel.saveState() }
        }
        .onChange(of: viewModel.selectedPeriod) {
            Task { await viewModel.saveState() }
        }
        .onChange(of: viewModel.selectedInvoiceIDs) {
            // Update single selection for detail view when selection changes
            if viewModel.selectedInvoiceIDs.count == 1,
               let id = viewModel.selectedInvoiceIDs.first {
                viewModel.selectedInvoice = viewModel.invoices.first { $0.id == id }
            } else if viewModel.selectedInvoiceIDs.isEmpty {
                viewModel.selectedInvoice = nil
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
                    Text("Exporting Invoices")
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

struct InvoiceRowView: View {
    let invoice: Invoice
    var sortOption: InvoiceSortOption = .issueDate

    private var formattedAmount: String {
        CurrencyFormatter.format(invoice.dueAmount, currency: invoice.currency)
    }

    private var dateValue: Date {
        switch sortOption {
        case .issueDate: invoice.issueDate
        case .dueDate: invoice.dueDate
        case .paidDate: invoice.paidAt ?? invoice.paidDate ?? invoice.issueDate
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
                    .lineLimit(2)
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
        InvoicesListView(viewModel: InvoicesViewModel(), showingSettings: .constant(false))
    }
}
