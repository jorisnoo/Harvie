//
//  InvoiceDetailView.swift
//  Harvester
//

import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers

struct InvoiceDetailView: View {
    let invoice: Invoice
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingSuccess = false

    private let pdfService = PDFService.shared
    private let keychainService = KeychainService.shared

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = invoice.currency
        return formatter.string(from: invoice.amount as NSDecimalNumber) ?? "\(invoice.amount)"
    }

    private var formattedDueAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = invoice.currency
        return formatter.string(from: invoice.dueAmount as NSDecimalNumber) ?? "\(invoice.dueAmount)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                clientSection
                amountsSection
                datesSection

                if let lineItems = invoice.lineItems, !lineItems.isEmpty {
                    lineItemsSection(lineItems)
                }

                if let notes = invoice.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                actionSection
            }
            .padding()
        }
        .navigationTitle("Invoice \(invoice.number)")
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Invoice with QR bill saved successfully.")
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.number)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let subject = invoice.subject {
                    Text(subject)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StateIndicator(state: invoice.state)
                .scaleEffect(1.5)
        }
    }

    private var clientSection: some View {
        GroupBox("Client") {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.client.name)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var amountsSection: some View {
        GroupBox("Amounts") {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Total:")
                        .foregroundStyle(.secondary)
                    Text(formattedAmount)
                        .fontWeight(.medium)
                }

                GridRow {
                    Text("Due:")
                        .foregroundStyle(.secondary)
                    Text(formattedDueAmount)
                        .fontWeight(.bold)
                        .foregroundStyle(invoice.state == .open ? .red : .primary)
                }

                if let tax = invoice.tax, let taxAmount = invoice.taxAmount {
                    GridRow {
                        Text("Tax (\(tax.formatted())%):")
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(taxAmount))
                    }
                }

                if let discount = invoice.discount, let discountAmount = invoice.discountAmount {
                    GridRow {
                        Text("Discount (\(discount.formatted())%):")
                            .foregroundStyle(.secondary)
                        Text("-\(formatCurrency(discountAmount))")
                            .foregroundStyle(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var datesSection: some View {
        GroupBox("Dates") {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Issue Date:")
                        .foregroundStyle(.secondary)
                    Text(invoice.issueDate.formatted(date: .long, time: .omitted))
                }

                GridRow {
                    Text("Due Date:")
                        .foregroundStyle(.secondary)
                    Text(invoice.dueDate.formatted(date: .long, time: .omitted))
                        .foregroundStyle(invoice.dueDate < Date() && invoice.state == .open ? .red : .primary)
                }

                if let sentAt = invoice.sentAt {
                    GridRow {
                        Text("Sent:")
                            .foregroundStyle(.secondary)
                        Text(sentAt.formatted(date: .long, time: .shortened))
                    }
                }

                if let paidAt = invoice.paidAt {
                    GridRow {
                        Text("Paid:")
                            .foregroundStyle(.secondary)
                        Text(paidAt.formatted(date: .long, time: .shortened))
                            .foregroundStyle(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lineItemsSection(_ items: [LineItem]) -> some View {
        GroupBox("Line Items") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.kind.capitalized)
                                .font(.headline)

                            if let description = item.description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Text("\(item.quantity.formatted()) x \(formatCurrency(item.unitPrice))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formatCurrency(item.amount))
                            .fontWeight(.medium)
                    }

                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func notesSection(_ notes: String) -> some View {
        GroupBox("Notes") {
            Text(notes)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                Button {
                    Task {
                        await downloadWithQRBill()
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Image(systemName: "doc.badge.plus")
                        Text("Download with QR Bill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isProcessing)

                Text("Downloads the invoice PDF from Harvest and appends a Swiss QR bill payment slip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func downloadWithQRBill() async {
        isProcessing = true
        error = nil

        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            let creditorInfo = try await keychainService.loadCreditorInfo()

            guard creditorInfo.isValid else {
                error = "Please configure your creditor information in Settings."
                isProcessing = false
                return
            }

            let pdf = try await pdfService.createInvoiceWithQRBill(
                invoice: invoice,
                credentials: credentials,
                creditorInfo: creditorInfo
            )

            await MainActor.run {
                showSavePanel(for: pdf)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    private func showSavePanel(for document: PDFDocument) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "Invoice-\(invoice.number)-QR.pdf"
        savePanel.title = "Save Invoice with QR Bill"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                Task {
                    do {
                        try await pdfService.savePDF(document, to: url)
                        await MainActor.run {
                            showingSuccess = true
                        }
                    } catch {
                        await MainActor.run {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = invoice.currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

#Preview {
    InvoiceDetailView(invoice: Invoice(
        id: 1,
        clientKey: "abc123",
        number: "INV-2024-001",
        purchaseOrder: nil,
        amount: 1500.00,
        dueAmount: 1500.00,
        tax: 7.7,
        taxAmount: 115.50,
        tax2: nil,
        tax2Amount: nil,
        discount: nil,
        discountAmount: nil,
        subject: "Web Development Services",
        notes: "Thank you for your business!",
        currency: "CHF",
        state: .open,
        periodStart: nil,
        periodEnd: nil,
        issueDate: Date(),
        dueDate: Date().addingTimeInterval(86400 * 30),
        sentAt: Date(),
        paidAt: nil,
        paidDate: nil,
        closedAt: nil,
        createdAt: Date(),
        updatedAt: Date(),
        client: ClientReference(id: 1, name: "Acme Corp"),
        lineItems: [
            LineItem(
                id: 1,
                kind: "Service",
                description: "Frontend development",
                quantity: 10,
                unitPrice: 150.00,
                amount: 1500.00,
                taxed: true,
                taxed2: false,
                project: nil
            )
        ]
    ))
}
