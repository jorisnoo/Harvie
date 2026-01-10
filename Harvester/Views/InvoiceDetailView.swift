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
    @State private var savedFilePath: String?
    @State private var creditorName: String = ""
    @State private var appSettings: AppSettings = .default

    // Subject editing
    @State private var editedSubject: String = ""
    @State private var lastSavedSubject: String = ""
    @State private var isSavingSubject = false
    @State private var subjectSaved = false

    // Notes editing
    @State private var editedNotes: String = ""
    @State private var lastSavedNotes: String = ""
    @State private var isSavingNotes = false
    @State private var notesSaved = false

    private let pdfService = PDFService.shared
    private let keychainService = KeychainService.shared
    private let apiService = HarvestAPIService.shared

    private var formattedAmount: String {
        formatCurrency(invoice.amount)
    }

    private var formattedDueAmount: String {
        formatCurrency(invoice.dueAmount)
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

                notesSection
            }
            .padding()
        }
        .navigationTitle("Invoice \(invoice.number)")
        .task {
            editedSubject = invoice.subject ?? ""
            lastSavedSubject = invoice.subject ?? ""
            editedNotes = invoice.notes ?? ""
            lastSavedNotes = invoice.notes ?? ""
            if let creditorInfo = try? await keychainService.loadCreditorInfo() {
                creditorName = creditorInfo.name
            }
            if let settings = try? await keychainService.loadAppSettings() {
                appSettings = settings
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await downloadWithQRBill()
                    }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Download with QR Bill", systemImage: "qrcode")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                .help("Download invoice PDF with Swiss QR bill")
            }
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .alert("Success", isPresented: $showingSuccess) {
            if let path = savedFilePath {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            if let path = savedFilePath {
                Text("Invoice saved to:\n\(path)")
            } else {
                Text("Invoice with QR bill saved successfully.")
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(invoice.number)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                StateIndicator(state: invoice.state)
            }

            HStack {
                TextField("Invoice title", text: $editedSubject)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.plain)
                    .onChange(of: editedSubject) {
                        subjectSaved = false
                    }

                if editedSubject != lastSavedSubject {
                    if subjectSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Button {
                        Task {
                            await saveSubject()
                        }
                    } label: {
                        if isSavingSubject {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isSavingSubject)
                    .help("Save title")
                }
            }
        }
    }

    private func saveSubject() async {
        isSavingSubject = true
        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            try await apiService.updateInvoiceSubject(
                invoiceId: invoice.id,
                subject: editedSubject,
                credentials: credentials
            )
            lastSavedSubject = editedSubject
            subjectSaved = true
        } catch {
            self.error = "Failed to save title: \(error.localizedDescription)"
        }
        isSavingSubject = false
    }

    private var clientSection: some View {
        GroupBox("Client") {
            Text(invoice.client.name)
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
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.headline)
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

    private var notesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $editedNotes)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .onChange(of: editedNotes) {
                        notesSaved = false
                    }

                if editedNotes != lastSavedNotes {
                    HStack {
                        Spacer()
                        if notesSaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                        Button {
                            Task {
                                await saveNotes()
                            }
                        } label: {
                            if isSavingNotes {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Save Notes")
                            }
                        }
                        .disabled(isSavingNotes)
                    }
                }
            }
        } label: {
            Text("Notes")
        }
    }

    private func saveNotes() async {
        isSavingNotes = true
        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            try await apiService.updateInvoiceNotes(
                invoiceId: invoice.id,
                notes: editedNotes,
                credentials: credentials
            )
            lastSavedNotes = editedNotes
            notesSaved = true
        } catch {
            self.error = "Failed to save notes: \(error.localizedDescription)"
        }
        isSavingNotes = false
    }

    private func downloadWithQRBill() async {
        isProcessing = true
        error = nil
        savedFilePath = nil

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

            // Load app settings to determine save behavior
            let appSettings: AppSettings
            do {
                appSettings = try await keychainService.loadAppSettings()
            } catch {
                appSettings = .default
            }

            await MainActor.run {
                savePDF(pdf, settings: appSettings)
            }
        } catch {
            self.error = error.localizedDescription
            isProcessing = false
        }
    }

    private var invoiceFileName: String {
        appSettings.generateFilename(
            invoiceNumber: invoice.number,
            creditorName: creditorName,
            clientName: invoice.client.name,
            issueDate: invoice.issueDate
        )
    }

    private func savePDF(_ document: PDFDocument, settings: AppSettings) {
        let fileName = invoiceFileName

        if settings.downloadBehavior == .useDefaultFolder,
           let folderURL = settings.downloadURL {
            // Start accessing security-scoped resource (for user-selected folders)
            let hasAccess = folderURL.startAccessingSecurityScopedResource()

            let fileURL = folderURL.appendingPathComponent(fileName)

            // If file exists, add a number
            var finalURL = fileURL
            var counter = 1
            let baseName = fileName.replacingOccurrences(of: ".pdf", with: "")
            while FileManager.default.fileExists(atPath: finalURL.path) {
                finalURL = folderURL.appendingPathComponent("\(baseName)_\(counter).pdf")
                counter += 1
            }

            // Try to save
            let success = document.write(to: finalURL)

            if hasAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }

            if success {
                savedFilePath = finalURL.path
                showingSuccess = true
                isProcessing = false
            } else {
                // Fall back to save panel if direct save fails
                showSavePanel(for: document, suggestedName: fileName)
            }
        } else {
            showSavePanel(for: document, suggestedName: fileName)
        }
    }

    private func showSavePanel(for document: PDFDocument, suggestedName: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = suggestedName
        savePanel.title = "Save Invoice with QR Bill"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                Task {
                    do {
                        try await pdfService.savePDF(document, to: url)
                        await MainActor.run {
                            savedFilePath = url.path
                            showingSuccess = true
                            isProcessing = false
                        }
                    } catch {
                        await MainActor.run {
                            self.error = error.localizedDescription
                            isProcessing = false
                        }
                    }
                }
            } else {
                isProcessing = false
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
