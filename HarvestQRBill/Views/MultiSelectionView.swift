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
                title: Strings.InvoiceDetail.changeIssueDate,
                message: Strings.MultiSelection.setIssueDateMessage(selectedInvoices.count),
                confirmLabel: Strings.Common.apply,
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
                    Button(Strings.Common.today) { batchIssueDate = Date() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(Calendar.current.isDateInToday(batchIssueDate))
                }

                DatePicker(Strings.InvoiceDetail.issueDate, selection: $batchIssueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                if viewModel.isUpdating {
                    batchProgressView
                }
            }
        }
        .sheet(isPresented: $showMarkAsSentSheet) {
            ConfirmationSheet(
                title: Strings.InvoiceDetail.markAsSent,
                message: Strings.MultiSelection.markAsSentMessage(selectedInvoices.count),
                detail: Strings.MultiSelection.sentDateDetail,
                confirmLabel: Strings.InvoiceDetail.markAsSent,
                isProcessing: viewModel.isUpdating,
                onConfirm: {
                    Task {
                        await viewModel.markSelectedAsSent()
                        if viewModel.showUpdateSuccess { showMarkAsSentSheet = false }
                    }
                },
                onCancel: { showMarkAsSentSheet = false },
                width: 300
            ) {
                if viewModel.isUpdating {
                    batchProgressView
                }
            }
        }
        .sheet(isPresented: $showMarkAsDraftSheet) {
            ConfirmationSheet(
                title: Strings.InvoiceDetail.markAsDraft,
                message: Strings.MultiSelection.markAsDraftMessage(selectedInvoices.count),
                confirmLabel: Strings.InvoiceDetail.markAsDraft,
                isProcessing: viewModel.isUpdating,
                onConfirm: {
                    Task {
                        await viewModel.markSelectedAsDraft()
                        if viewModel.showUpdateSuccess { showMarkAsDraftSheet = false }
                    }
                },
                onCancel: { showMarkAsDraftSheet = false }
            ) {
                if viewModel.isUpdating {
                    batchProgressView
                }
            }
        }
    }

    private var draftActionsSection: some View {
        HStack(spacing: 12) {
            Button {
                batchIssueDate = Date()
                showChangeDateSheet = true
            } label: {
                Label(Strings.InvoiceDetail.changeDate, systemImage: "calendar")
                    .frame(maxWidth: 150)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isUpdating)

            Button {
                showMarkAsSentSheet = true
            } label: {
                Label(Strings.InvoiceDetail.markAsSent, systemImage: "paperplane")
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
            Label(Strings.InvoiceDetail.markAsDraft, systemImage: "pencil")
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

            Text(Strings.MultiSelection.invoicesSelected(selectedInvoices.count))
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var summaryStats: some View {
        HStack(spacing: 24) {
            VStack {
                Text(Strings.MultiSelection.total)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(totalAmount, currency: primaryCurrency))
                    .font(.title3)
                    .fontWeight(.medium)
            }

            Divider().frame(height: 32)

            VStack {
                Text(Strings.MultiSelection.clients)
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
                Label(Strings.InvoicesList.exportWithQRBill, systemImage: "qrcode")
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
                Label(Strings.InvoicesList.exportWithoutQRBill, systemImage: "doc.text")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var batchProgressView: some View {
        VStack(spacing: 6) {
            ProgressView(
                value: Double(viewModel.updatedCount),
                total: Double(viewModel.updateTotalCount)
            )
            Text("\(viewModel.updatedCount) of \(viewModel.updateTotalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var invoicesList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(selectedInvoices) { invoice in
                    HStack {
                        Text(invoice.number)
                            .fontWeight(.medium)
                        Text(Strings.MultiSelection.bullet)
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
