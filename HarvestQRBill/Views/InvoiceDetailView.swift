//
//  InvoiceDetailView.swift
//  HarvestQRBill
//

import AppKit
import os.log
import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "InvoiceDetail")

struct InvoiceDetailView: View {
    let invoice: Invoice
    var onRefresh: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var isProcessing = false
    @State private var isPreviewing = false
    @State private var error: String?
    @State private var showingSuccess = false
    @State private var savedFilePath: String?
    @State private var creditorName: String = ""
    @State private var canExportWithQRBill = false
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

    // Issue date editing (draft only)
    @State private var editedIssueDate: Date = Date()
    @State private var lastSavedIssueDate: Date = Date()
    @State private var isSavingIssueDate = false
    @State private var issueDateSaved = false

    // Mark as sent / draft
    @State private var isMarkingAsSent = false
    @State private var showMarkAsSentSheet = false
    @State private var showMarkAsSentSuccess = false
    @State private var isMarkingAsDraft = false
    @State private var showMarkAsDraftSheet = false
    @State private var showMarkAsDraftSuccess = false

    // Change issue date modal
    @State private var showChangeDateSheet = false

    private let pdfService = PDFService.shared
    private let keychainService = KeychainService.shared
    private let apiService = HarvestAPIService.shared

    private var formattedAmount: String {
        CurrencyFormatter.format(invoice.amount, currency: invoice.currency)
    }

    private var formattedDueAmount: String {
        CurrencyFormatter.format(invoice.dueAmount, currency: invoice.currency)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                amountsSection

                if let lineItems = invoice.lineItems, !lineItems.isEmpty {
                    lineItemsSection(lineItems)
                }

                datesSection
                notesSection
            }
            .padding()
        }
        .navigationTitle("Invoice \(invoice.number)")
        .task(id: invoice.id) {
            editedSubject = invoice.subject ?? ""
            lastSavedSubject = invoice.subject ?? ""
            editedNotes = invoice.notes ?? ""
            lastSavedNotes = invoice.notes ?? ""
            editedIssueDate = invoice.issueDate
            lastSavedIssueDate = invoice.issueDate
            issueDateSaved = false
            if let creditorInfo = try? await keychainService.loadCreditorInfo() {
                creditorName = creditorInfo.name
                canExportWithQRBill = creditorInfo.isValid
            }
            if let settings = try? await keychainService.loadAppSettings() {
                appSettings = settings
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await previewWithQRBill() }
                } label: {
                    if isPreviewing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Preview", systemImage: "eye")
                    }
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(isPreviewing || isProcessing || !canExportWithQRBill)
                .help(canExportWithQRBill ? "Preview invoice PDF with Swiss QR bill (Space)" : "Configure creditor info in Settings first")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await downloadWithQRBill() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Export QR Bill", systemImage: "square.and.arrow.down")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || isPreviewing || !canExportWithQRBill)
                .help(canExportWithQRBill ? "Download invoice PDF with Swiss QR bill" : "Configure creditor info in Settings first")
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if invoice.state == .draft {
                        Button {
                            showMarkAsSentSheet = true
                        } label: {
                            Label("Mark as Sent", systemImage: "paperplane")
                        }
                        .disabled(isMarkingAsSent)

                        Button {
                            editedIssueDate = invoice.issueDate
                            showChangeDateSheet = true
                        } label: {
                            Label("Change Date", systemImage: "calendar")
                        }
                    }

                    if invoice.state == .open {
                        Button {
                            showMarkAsDraftSheet = true
                        } label: {
                            Label("Mark as Draft", systemImage: "pencil")
                        }
                        .disabled(isMarkingAsDraft)
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .disabled(invoice.state == .paid || invoice.state == .closed)
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Invoice title", text: $editedSubject)
                    .font(.title2)
                    .fontWeight(.semibold)
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
                        Task { await saveSubject() }
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

                Spacer()

                StateIndicator(state: invoice.state)
            }

            HStack(spacing: 4) {
                Text(invoice.number)
                Text("·")
                Text(invoice.client.name)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showChangeDateSheet) {
            ConfirmationSheet(
                title: "Change Issue Date",
                confirmLabel: "Save",
                isProcessing: isSavingIssueDate,
                onConfirm: {
                    Task {
                        await saveIssueDate()
                        if issueDateSaved { showChangeDateSheet = false }
                    }
                },
                onCancel: { showChangeDateSheet = false },
                width: 300
            ) {
                HStack {
                    Spacer()
                    Button("Today") { editedIssueDate = Date() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(Calendar.current.isDateInToday(editedIssueDate))
                }

                DatePicker("Issue Date", selection: $editedIssueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
        }
        .sheet(isPresented: $showMarkAsSentSheet) {
            ConfirmationSheet(
                title: "Mark as Sent",
                message: "Mark invoice \(invoice.number) as sent?",
                detail: "The sent date will be set to now.",
                confirmLabel: "Mark as Sent",
                isProcessing: isMarkingAsSent,
                onConfirm: {
                    Task {
                        await markAsSent()
                        if showMarkAsSentSuccess { showMarkAsSentSheet = false }
                    }
                },
                onCancel: { showMarkAsSentSheet = false }
            )
        }
        .alert("Invoice Sent", isPresented: $showMarkAsSentSuccess) {
            Button("OK") { }
        } message: {
            Text("Invoice \(invoice.number) has been marked as sent.")
        }
        .sheet(isPresented: $showMarkAsDraftSheet) {
            ConfirmationSheet(
                title: "Mark as Draft",
                message: "Revert invoice \(invoice.number) to draft?",
                confirmLabel: "Mark as Draft",
                isProcessing: isMarkingAsDraft,
                onConfirm: {
                    Task {
                        await markAsDraft()
                        if showMarkAsDraftSuccess { showMarkAsDraftSheet = false }
                    }
                },
                onCancel: { showMarkAsDraftSheet = false }
            )
        }
        .alert("Invoice Reverted", isPresented: $showMarkAsDraftSuccess) {
            Button("OK") { }
        } message: {
            Text("Invoice \(invoice.number) has been reverted to draft.")
        }
    }

    // MARK: - Amounts

    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDueAmount)
                .font(.title)
                .fontWeight(.bold)

            if invoice.dueAmount != invoice.amount {
                Text("of \(formattedAmount) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Issued \(invoice.issueDate.formatted(date: .long, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Due \(invoice.dueDate.formatted(date: .long, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let tax = invoice.tax, let taxAmount = invoice.taxAmount {
                Text("Incl. \(tax.formatted())% tax (\(CurrencyFormatter.format(taxAmount, currency: invoice.currency)))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let discount = invoice.discount, let discountAmount = invoice.discountAmount {
                Text("Discount \(discount.formatted())%: -\(CurrencyFormatter.format(discountAmount, currency: invoice.currency))")
                    .font(.caption)
            }
        }
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let sentAt = invoice.sentAt {
                Text("Sent \(sentAt.formatted(date: .long, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let paidAt = invoice.paidAt {
                Text("Paid \(paidAt.formatted(date: .long, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Line Items

    private func lineItemsSection(_ items: [LineItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 12)

            ForEach(items) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let description = item.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                        }

                        Text("\(item.quantity.formatted()) × \(CurrencyFormatter.format(item.unitPrice, currency: invoice.currency))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(CurrencyFormatter.format(item.amount, currency: invoice.currency))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                if item.id != items.last?.id {
                    Divider()
                }
            }

            Divider()
                .padding(.vertical, 12)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            TextEditor(text: $editedNotes)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .onChange(of: editedNotes) {
                    notesSaved = false
                }

            if editedNotes != lastSavedNotes {
                HStack {
                    Spacer()
                    if notesSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Button {
                        Task { await saveNotes() }
                    } label: {
                        if isSavingNotes {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isSavingNotes)
                }
            }
        }
    }

    // MARK: - API Actions

    private func performAPIAction(
        label: String,
        action: (HarvestCredentials) async throws -> Void
    ) async -> Bool {
        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            try await action(credentials)
            return true
        } catch let apiError as HarvestAPIService.APIError {
            self.error = "Failed to \(label): \(apiError.localizedDescription)"
        } catch {
            #if DEBUG
            logger.error("Failed to \(label): \(error.localizedDescription)")
            #endif
            self.error = "Failed to \(label). Please try again."
        }
        return false
    }

    private func saveSubject() async {
        isSavingSubject = true
        let success = await performAPIAction(label: "save title") { credentials in
            try await apiService.updateInvoiceSubject(
                invoiceId: invoice.id, subject: editedSubject, credentials: credentials
            )
        }
        if success {
            lastSavedSubject = editedSubject
            subjectSaved = true
        }
        isSavingSubject = false
    }

    private func saveNotes() async {
        isSavingNotes = true
        let success = await performAPIAction(label: "save notes") { credentials in
            try await apiService.updateInvoiceNotes(
                invoiceId: invoice.id, notes: editedNotes, credentials: credentials
            )
        }
        if success {
            lastSavedNotes = editedNotes
            notesSaved = true
        }
        isSavingNotes = false
    }

    private func saveIssueDate() async {
        isSavingIssueDate = true
        let success = await performAPIAction(label: "save issue date") { credentials in
            try await apiService.updateInvoiceIssueDate(
                invoiceId: invoice.id, issueDate: editedIssueDate, credentials: credentials
            )
        }
        if success {
            lastSavedIssueDate = editedIssueDate
            issueDateSaved = true
            onRefresh?()
        }
        isSavingIssueDate = false
    }

    private func markAsSent() async {
        isMarkingAsSent = true
        let success = await performAPIAction(label: "mark as sent") { credentials in
            try await apiService.markInvoiceAsSent(invoiceId: invoice.id, credentials: credentials)
        }
        if success {
            showMarkAsSentSuccess = true
            onRefresh?()
        }
        isMarkingAsSent = false
    }

    private func markAsDraft() async {
        isMarkingAsDraft = true
        let success = await performAPIAction(label: "mark as draft") { credentials in
            try await apiService.markInvoiceAsDraft(invoiceId: invoice.id, credentials: credentials)
        }
        if success {
            showMarkAsDraftSuccess = true
            onRefresh?()
        }
        isMarkingAsDraft = false
    }

    // MARK: - PDF Generation

    private func generatePDF() async throws -> (pdf: PDFDocument, settings: AppSettings) {
        #if DEBUG
        let creditorInfo = (try? await keychainService.loadCreditorInfo()) ?? DemoDataProvider.defaultCreditorInfo
        #else
        let creditorInfo = (try? await keychainService.loadCreditorInfo()) ?? .empty
        #endif

        guard creditorInfo.isValid else {
            throw GenerationError.invalidCreditor
        }

        let settings = (try? await keychainService.loadAppSettings()) ?? .default

        if settings.pdfSource == .template,
           let templateId = settings.selectedTemplateId,
           let template = loadTemplate(id: templateId) {
            let credentials = try? await keychainService.loadHarvestCredentials()
            let pdf = try await pdfService.createInvoiceFromTemplate(
                invoice: invoice,
                template: template,
                creditorInfo: creditorInfo,
                credentials: credentials
            )
            return (pdf, settings)
        }

        #if DEBUG
        if settings.isDemoMode {
            let pdf = try await pdfService.createDemoInvoiceWithQRBill(
                invoice: invoice, creditorInfo: creditorInfo
            )
            return (pdf, settings)
        }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        let pdf = try await pdfService.createInvoiceWithQRBill(
            invoice: invoice, credentials: credentials, creditorInfo: creditorInfo
        )
        return (pdf, settings)
    }

    private func previewWithQRBill() async {
        isPreviewing = true
        error = nil

        do {
            let (pdf, _) = try await generatePDF()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(invoiceFileName)
            pdf.write(to: tempURL)
            NSWorkspace.shared.open(tempURL)
            Analytics.pdfPreviewed()
        } catch {
            handlePDFError(error, context: "Preview")
        }

        isPreviewing = false
    }

    private func downloadWithQRBill() async {
        isProcessing = true
        error = nil
        savedFilePath = nil

        do {
            let (pdf, settings) = try await generatePDF()
            let result = try await InvoiceFileSaver.save(
                pdf, fileName: invoiceFileName, settings: settings, pdfService: pdfService
            )

            switch result {
            case .saved(let path):
                savedFilePath = path
                showingSuccess = true
            case .cancelled:
                break
            }
        } catch {
            handlePDFError(error, context: "Download")
        }

        isProcessing = false
    }

    private func handlePDFError(_ error: Error, context: String) {
        if let apiError = error as? HarvestAPIService.APIError {
            self.error = apiError.localizedDescription
        } else if let pdfError = error as? PDFService.PDFError {
            self.error = pdfError.localizedDescription
        } else {
            #if DEBUG
            logger.error("\(context) failed: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
        }
    }

    private func loadTemplate(id: UUID) -> InvoiceTemplate? {
        let descriptor = FetchDescriptor<InvoiceTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private var invoiceFileName: String {
        let rawFilename = appSettings.generateFilename(
            invoiceNumber: invoice.number,
            creditorName: creditorName,
            clientName: invoice.client.name,
            date: invoice.issueDate,
            issueDate: invoice.issueDate,
            dueDate: invoice.dueDate,
            paidDate: invoice.paidAt ?? invoice.paidDate
        )
        return InvoiceFileSaver.sanitizeFilename(rawFilename)
    }

    private enum GenerationError: LocalizedError {
        case invalidCreditor

        var errorDescription: String? {
            "Please configure your creditor information in Settings."
        }
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
