//
//  MultiSelectionView.swift
//  HarvestQRBill
//

import SwiftUI

struct MultiSelectionView: View {
    @Bindable var viewModel: InvoicesViewModel

    @State private var batchIssueDate = Date()
    @State private var showChangeDateSheet = false
    @State private var showMarkAsSentSheet = false
    @State private var showMarkAsDraftSheet = false

    private var selectedInvoices: [Invoice] {
        viewModel.selectedInvoices
    }

    private var totalAmount: Decimal {
        selectedInvoices.reduce(0) { $0 + $1.displayAmount }
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

            if viewModel.allSelectedAreDrafts {
                draftActionsSection
            }

            if viewModel.allSelectedAreOpen {
                openActionsSection
            }

            Divider()
                .padding(.horizontal, 40)
            invoicesList
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showChangeDateSheet) {
            ConfirmationSheet(
                title: "Change Issue Date",
                message: "Set issue date for \(selectedInvoices.count) invoice(s)",
                confirmLabel: "Apply",
                isProcessing: viewModel.isUpdating,
                onConfirm: {
                    Task {
                        await viewModel.updateIssueDateForSelected(to: batchIssueDate)
                        if viewModel.showUpdateSuccess { showChangeDateSheet = false }
                    }
                },
                onCancel: { showChangeDateSheet = false },
                width: 300
            ) {
                HStack {
                    Spacer()
                    Button("Today") { batchIssueDate = Date() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(Calendar.current.isDateInToday(batchIssueDate))
                }

                DatePicker("Issue Date", selection: $batchIssueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
        }
        .sheet(isPresented: $showMarkAsSentSheet) {
            ConfirmationSheet(
                title: "Mark as Sent",
                message: "Mark \(selectedInvoices.count) invoice(s) as sent?",
                detail: "The sent date will be set to the current time.",
                confirmLabel: "Mark as Sent",
                isProcessing: viewModel.isUpdating,
                onConfirm: {
                    Task {
                        await viewModel.markSelectedAsSent()
                        if viewModel.showUpdateSuccess { showMarkAsSentSheet = false }
                    }
                },
                onCancel: { showMarkAsSentSheet = false },
                width: 300
            )
        }
        .sheet(isPresented: $showMarkAsDraftSheet) {
            ConfirmationSheet(
                title: "Mark as Draft",
                message: "Revert \(selectedInvoices.count) invoice(s) to draft?",
                confirmLabel: "Mark as Draft",
                isProcessing: viewModel.isUpdating,
                onConfirm: {
                    Task {
                        await viewModel.markSelectedAsDraft()
                        if viewModel.showUpdateSuccess { showMarkAsDraftSheet = false }
                    }
                },
                onCancel: { showMarkAsDraftSheet = false }
            )
        }
    }

    private var draftActionsSection: some View {
        HStack(spacing: 12) {
            Button {
                batchIssueDate = Date()
                showChangeDateSheet = true
            } label: {
                Label("Change Date", systemImage: "calendar")
                    .frame(maxWidth: 150)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isUpdating)

            Button {
                showMarkAsSentSheet = true
            } label: {
                Label("Mark as Sent", systemImage: "paperplane")
                    .frame(maxWidth: 150)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isUpdating)
        }
    }

    private var openActionsSection: some View {
        Button {
            showMarkAsDraftSheet = true
        } label: {
            Label("Mark as Draft", systemImage: "pencil")
                .frame(maxWidth: 150)
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isUpdating)
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
                        Text(CurrencyFormatter.format(invoice.displayAmount, currency: invoice.currency))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
