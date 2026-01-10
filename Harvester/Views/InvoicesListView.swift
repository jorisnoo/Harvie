//
//  InvoicesListView.swift
//  Harvester
//

import SwiftUI

struct InvoicesListView: View {
    @Bindable var viewModel: InvoicesViewModel

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
                    InvoiceRowView(invoice: invoice)
                        .tag(invoice.id)
                }
                .contextMenu(forSelectionType: Int.self) { selectedIDs in
                    if !selectedIDs.isEmpty {
                        Button {
                            Task {
                                await viewModel.exportSelectedInvoices(withQRBill: true)
                            }
                        } label: {
                            Label("Export with QR Bill", systemImage: "qrcode")
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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                } label: {
                    Label("Selection", systemImage: "checkmark.circle")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
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
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }

            ToolbarItem(placement: .primaryAction) {
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

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onChange(of: viewModel.stateFilter) {
            Task {
                await viewModel.loadInvoices()
            }
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

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = invoice.currency
        return formatter.string(from: invoice.dueAmount as NSDecimalNumber) ?? "\(invoice.dueAmount)"
    }

    private var formattedDate: String {
        invoice.dueDate.formatted(date: .abbreviated, time: .omitted)
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
                    Text("Due: \(formattedDate)")
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
        case .draft:
            return .gray
        case .open:
            return .orange
        case .paid:
            return .green
        case .closed:
            return .blue
        }
    }

    var body: some View {
        Text(state.rawValue.capitalized)
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
