//
//  InvoicesListView.swift
//  Harvester
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
                        Task {
                            await viewModel.loadInvoices()
                        }
                    }
                }
            } else if viewModel.invoices.isEmpty {
                ContentUnavailableView {
                    Label("No Invoices", systemImage: "doc.text")
                } description: {
                    Text("No \(viewModel.stateFilter?.rawValue ?? "") invoices found.")
                } actions: {
                    Button("Refresh") {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                }
            } else {
                List(viewModel.sortedInvoices, selection: $viewModel.selectedInvoiceIDs) { invoice in
                    InvoiceRowView(invoice: invoice, sortOption: viewModel.sortOption)
                        .tag(invoice.id)
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

                        Button {
                            Task {
                                await viewModel.exportSelectedInvoices(withQRBill: false)
                            }
                        } label: {
                            Label("Export without QR Bill", systemImage: "doc.text")
                        }
                    }
                } primaryAction: { selectedIDs in
                    // Double-click: show first selected invoice in detail
                    if let firstID = selectedIDs.first {
                        viewModel.selectedInvoice = viewModel.invoices.first { $0.id == firstID }
                    }
                }
            }
        }
        .navigationTitle("Invoices")
        .navigationSubtitle(viewModel.isRefreshing ? "Updating..." : "")
        .overlay {
            if viewModel.isExporting {
                ExportProgressOverlay(
                    progress: viewModel.exportProgress,
                    message: viewModel.exportProgressMessage
                )
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

                    // For multiselect:
                    // Menu {
                    //     ForEach(InvoiceState.allCases, id: \.self) { state in
                    //         Button {
                    //             if viewModel.stateFilters.contains(state) {
                    //                 viewModel.stateFilters.remove(state)
                    //             } else {
                    //                 viewModel.stateFilters.insert(state)
                    //             }
                    //         } label: {
                    //             HStack {
                    //                 Text(state.displayName)
                    //                 if viewModel.stateFilters.contains(state) {
                    //                     Image(systemName: "checkmark")
                    //                 }
                    //             }
                    //         }
                    //     }
                    //     Divider()
                    //     Button("Clear Filter") {
                    //         viewModel.stateFilters.removeAll()
                    //     }
                    // } label: {
                    //     Label("Filter", systemImage: viewModel.stateFilters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    // }

                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
        }
        .onChange(of: viewModel.stateFilter) {
            Task {
                await viewModel.loadInvoices()
            }
        }
        // For multiselect: .onChange(of: viewModel.stateFilters) { ... }
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

    private var dateLabel: String {
        switch sortOption {
        case .issueDate: "Issued"
        case .dueDate: "Due"
        case .paidDate: "Paid"
        }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.number)
                    .font(.headline)

                Text(invoice.client.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text("\(dateLabel): \(formattedDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    StateIndicator(state: invoice.state)
                }
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
        InvoicesListView(viewModel: InvoicesViewModel(), showingSettings: .constant(false))
    }
}
