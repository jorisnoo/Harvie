//
//  MultiSelectionView.swift
//  HarvestQRBill
//

import SwiftUI

struct MultiSelectionView: View {
    @Bindable var viewModel: InvoicesViewModel

    private var selectedInvoices: [Invoice] {
        viewModel.selectedInvoices
    }

    private var totalAmount: Decimal {
        selectedInvoices.reduce(0) { $0 + $1.dueAmount }
    }

    private var uniqueClients: Int {
        Set(selectedInvoices.map { $0.client.id }).count
    }

    private var primaryCurrency: String {
        selectedInvoices.first?.currency ?? "CHF"
    }

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            summaryStats
            actionButtons
            Divider()
                .padding(.horizontal, 40)
            invoicesList
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("\(selectedInvoices.count) Invoices Selected")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var summaryStats: some View {
        HStack(spacing: 24) {
            VStack {
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(totalAmount, currency: primaryCurrency))
                    .font(.title3)
                    .fontWeight(.medium)
            }

            Divider().frame(height: 32)

            VStack {
                Text("Clients")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(uniqueClients)")
                    .font(.title3)
                    .fontWeight(.medium)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.exportSelectedInvoices(withQRBill: true)
                }
            } label: {
                Label("Export with QR Bill", systemImage: "qrcode")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canExportWithQRBill)

            Button {
                Task {
                    await viewModel.exportSelectedInvoices(withQRBill: false)
                }
            } label: {
                Label("Export without QR Bill", systemImage: "doc.text")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var invoicesList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(selectedInvoices) { invoice in
                    HStack {
                        Text(invoice.number)
                            .fontWeight(.medium)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(invoice.client.name)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.format(invoice.dueAmount, currency: invoice.currency))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
