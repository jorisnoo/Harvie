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
                List(viewModel.invoices, selection: $viewModel.selectedInvoice) { invoice in
                    InvoiceRowView(invoice: invoice)
                        .tag(invoice)
                }
            }
        }
        .navigationTitle("Invoices")
        .toolbar {
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

    private var isOverdue: Bool {
        invoice.state == .open && invoice.dueDate < Date()
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
                    .foregroundStyle(isOverdue ? .red : .primary)

                HStack(spacing: 4) {
                    Text("Due: \(formattedDate)")
                        .font(.caption)
                        .foregroundStyle(isOverdue ? .red : .secondary)

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
