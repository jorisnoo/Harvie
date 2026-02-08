//
//  InvoiceDetailView.swift
//  HarvestQRBill
//

import AppKit
import os.log
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "InvoiceDetail")

struct InvoiceDetailView: View {
    let invoice: Invoice

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
                    Task {
                        await previewWithQRBill()
                    }
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
                    Task {
                        await downloadWithQRBill()
                    }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Subject + State + Actions
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

                Spacer()

                StateIndicator(state: invoice.state)
            }

            // Row 2: Metadata
            HStack(spacing: 4) {
                Text(invoice.number)
                Text("·")
                Text(invoice.client.name)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showChangeDateSheet) {
            ChangeDateSheet(
                date: $editedIssueDate,
                isSaving: isSavingIssueDate,
                onSave: {
                    Task {
                        await saveIssueDate()
                        if issueDateSaved {
                            showChangeDateSheet = false
                        }
                    }
                },
                onCancel: {
                    showChangeDateSheet = false
                }
            )
        }
        .sheet(isPresented: $showMarkAsSentSheet) {
            MarkAsSentSheet(
                invoiceNumber: invoice.number,
                isMarking: isMarkingAsSent,
                onConfirm: {
                    Task {
                        await markAsSent()
                        if showMarkAsSentSuccess {
                            showMarkAsSentSheet = false
                        }
                    }
                },
                onCancel: {
                    showMarkAsSentSheet = false
                }
            )
        }
        .alert("Invoice Sent", isPresented: $showMarkAsSentSuccess) {
            Button("OK") { }
        } message: {
            Text("Invoice \(invoice.number) has been marked as sent.")
        }
        .sheet(isPresented: $showMarkAsDraftSheet) {
            MarkAsDraftSheet(
                invoiceNumber: invoice.number,
                isMarking: isMarkingAsDraft,
                onConfirm: {
                    Task {
                        await markAsDraft()
                        if showMarkAsDraftSuccess {
                            showMarkAsDraftSheet = false
                        }
                    }
                },
                onCancel: {
                    showMarkAsDraftSheet = false
                }
            )
        }
        .alert("Invoice Reverted", isPresented: $showMarkAsDraftSuccess) {
            Button("OK") { }
        } message: {
            Text("Invoice \(invoice.number) has been reverted to draft.")
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
        } catch let apiError as HarvestAPIService.APIError {
            self.error = "Failed to save title: \(apiError.localizedDescription)"
        } catch {
            #if DEBUG
            logger.error("Failed to save subject: \(error.localizedDescription)")
            #endif
            self.error = "Failed to save title. Please try again."
        }
        isSavingSubject = false
    }

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
//                    .foregroundStyle(.green)
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

    private func saveIssueDate() async {
        isSavingIssueDate = true
        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            try await apiService.updateInvoiceIssueDate(
                invoiceId: invoice.id,
                issueDate: editedIssueDate,
                credentials: credentials
            )
            lastSavedIssueDate = editedIssueDate
            issueDateSaved = true
        } catch let apiError as HarvestAPIService.APIError {
            self.error = "Failed to save issue date: \(apiError.localizedDescription)"
        } catch {
            #if DEBUG
            logger.error("Failed to save issue date: \(error.localizedDescription)")
            #endif
            self.error = "Failed to save issue date. Please try again."
        }
        isSavingIssueDate = false
    }

    private func markAsSent() async {
        isMarkingAsSent = true
        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            try await apiService.markInvoiceAsSent(
                invoiceId: invoice.id,
                credentials: credentials
            )
            showMarkAsSentSuccess = true
        } catch let apiError as HarvestAPIService.APIError {
            self.error = "Failed to mark as sent: \(apiError.localizedDescription)"
        } catch {
            #if DEBUG
            logger.error("Failed to mark as sent: \(error.localizedDescription)")
            #endif
            self.error = "Failed to mark as sent. Please try again."
        }
        isMarkingAsSent = false
    }

    private func markAsDraft() async {
        isMarkingAsDraft = true
        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            try await apiService.markInvoiceAsDraft(
                invoiceId: invoice.id,
                credentials: credentials
            )
            showMarkAsDraftSuccess = true
        } catch let apiError as HarvestAPIService.APIError {
            self.error = "Failed to mark as draft: \(apiError.localizedDescription)"
        } catch {
            #if DEBUG
            logger.error("Failed to mark as draft: \(error.localizedDescription)")
            #endif
            self.error = "Failed to mark as draft. Please try again."
        }
        isMarkingAsDraft = false
    }

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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        Task {
                            await saveNotes()
                        }
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
        } catch let apiError as HarvestAPIService.APIError {
            self.error = "Failed to save notes: \(apiError.localizedDescription)"
        } catch {
            #if DEBUG
            logger.error("Failed to save notes: \(error.localizedDescription)")
            #endif
            self.error = "Failed to save notes. Please try again."
        }
        isSavingNotes = false
    }

    private func previewWithQRBill() async {
        isPreviewing = true
        error = nil

        do {
            let settings = (try? await keychainService.loadAppSettings()) ?? .default
            let creditorInfo = (try? await keychainService.loadCreditorInfo()) ?? DemoDataProvider.defaultCreditorInfo

            guard creditorInfo.isValid else {
                error = "Please configure your creditor information in Settings."
                isPreviewing = false
                return
            }

            let pdf: PDFDocument
            if settings.isDemoMode {
                pdf = try await pdfService.createDemoInvoiceWithQRBill(
                    invoice: invoice,
                    creditorInfo: creditorInfo
                )
            } else {
                let credentials = try await keychainService.loadHarvestCredentials()
                pdf = try await pdfService.createInvoiceWithQRBill(
                    invoice: invoice,
                    credentials: credentials,
                    creditorInfo: creditorInfo
                )
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(invoiceFileName).pdf")

            pdf.write(to: tempURL)

            NSWorkspace.shared.open(tempURL)
        } catch let apiError as HarvestAPIService.APIError {
            self.error = apiError.localizedDescription
        } catch let pdfError as PDFService.PDFError {
            self.error = pdfError.localizedDescription
        } catch {
            #if DEBUG
            logger.error("Preview failed: \(error.localizedDescription)")
            #endif
            self.error = "Failed to generate preview. Please try again."
        }

        isPreviewing = false
    }

    private func downloadWithQRBill() async {
        isProcessing = true
        error = nil
        savedFilePath = nil

        do {
            let settings = (try? await keychainService.loadAppSettings()) ?? .default
            let creditorInfo = (try? await keychainService.loadCreditorInfo()) ?? DemoDataProvider.defaultCreditorInfo

            guard creditorInfo.isValid else {
                error = "Please configure your creditor information in Settings."
                isProcessing = false
                return
            }

            let pdf: PDFDocument
            if settings.isDemoMode {
                pdf = try await pdfService.createDemoInvoiceWithQRBill(
                    invoice: invoice,
                    creditorInfo: creditorInfo
                )
            } else {
                let credentials = try await keychainService.loadHarvestCredentials()
                pdf = try await pdfService.createInvoiceWithQRBill(
                    invoice: invoice,
                    credentials: credentials,
                    creditorInfo: creditorInfo
                )
            }

            await MainActor.run {
                savePDF(pdf, settings: settings)
            }
        } catch let apiError as HarvestAPIService.APIError {
            self.error = apiError.localizedDescription
            isProcessing = false
        } catch let pdfError as PDFService.PDFError {
            self.error = pdfError.localizedDescription
            isProcessing = false
        } catch {
            #if DEBUG
            logger.error("Download failed: \(error.localizedDescription)")
            #endif
            self.error = "Failed to download invoice. Please try again."
            isProcessing = false
        }
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

        return sanitizeFilename(rawFilename)
    }

    /// Removes path traversal components and invalid characters from a filename
    private func sanitizeFilename(_ filename: String) -> String {
        var sanitized = filename
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        // Remove leading dots and dashes
        while sanitized.hasPrefix(".") || sanitized.hasPrefix("-") {
            sanitized = String(sanitized.dropFirst())
        }

        // Ensure it ends with .pdf
        if !sanitized.lowercased().hasSuffix(".pdf") {
            sanitized += ".pdf"
        }

        return sanitized.isEmpty ? "invoice.pdf" : sanitized
    }

    /// Validates that the final file path is within the intended folder
    private func isValidPath(_ fileURL: URL, within folderURL: URL) -> Bool {
        let resolvedFile = fileURL.standardizedFileURL.path
        let resolvedFolder = folderURL.standardizedFileURL.path

        return resolvedFile.hasPrefix(resolvedFolder + "/") || resolvedFile.hasPrefix(resolvedFolder)
    }

    private func savePDF(_ document: PDFDocument, settings: AppSettings) {
        let fileName = invoiceFileName

        if settings.downloadBehavior == .useDefaultFolder,
           let folderURL = settings.downloadURL {
            // Start accessing security-scoped resource (for user-selected folders)
            let hasAccess = folderURL.startAccessingSecurityScopedResource()

            let fileURL = folderURL.appendingPathComponent(fileName)

            // Validate path traversal - ensure file stays within the intended folder
            guard isValidPath(fileURL, within: folderURL) else {
                if hasAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                }
                showSavePanel(for: document, suggestedName: "invoice.pdf")
                return
            }

            // If file exists, add a number
            var finalURL = fileURL
            var counter = 1
            let baseName = fileName.replacingOccurrences(of: ".pdf", with: "")
            while FileManager.default.fileExists(atPath: finalURL.path) {
                let numberedName = "\(baseName)_\(counter).pdf"
                finalURL = folderURL.appendingPathComponent(numberedName)
                // Re-validate to ensure numbered filename also stays within folder
                guard isValidPath(finalURL, within: folderURL) else {
                    if hasAccess {
                        folderURL.stopAccessingSecurityScopedResource()
                    }
                    showSavePanel(for: document, suggestedName: "invoice.pdf")
                    return
                }
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
                Analytics.pdfExported()
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
                            Analytics.pdfExported()
                        }
                    } catch let pdfError as PDFService.PDFError {
                        await MainActor.run {
                            self.error = pdfError.localizedDescription
                            isProcessing = false
                        }
                    } catch {
                        #if DEBUG
                        logger.error("Save failed: \(error.localizedDescription)")
                        #endif
                        await MainActor.run {
                            self.error = "Failed to save file. Please try again."
                            isProcessing = false
                        }
                    }
                }
            } else {
                isProcessing = false
            }
        }
    }

}

private struct ChangeDateSheet: View {
    @Binding var date: Date
    let isSaving: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Change Issue Date")
                    .font(.headline)

                Spacer()

                Button("Today") {
                    date = Date()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isToday)
            }

            DatePicker(
                "Issue Date",
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

private struct MarkAsSentSheet: View {
    let invoiceNumber: String
    let isMarking: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Mark as Sent")
                .font(.headline)

            Text("Mark invoice \(invoiceNumber) as sent?")

            Text("The sent date will be set to now.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Mark as Sent") {
                    onConfirm()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(isMarking)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

private struct MarkAsDraftSheet: View {
    let invoiceNumber: String
    let isMarking: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Mark as Draft")
                .font(.headline)

            Text("Revert invoice \(invoiceNumber) to draft?")

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("Mark as Draft") {
                    onConfirm()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(isMarking)
            }
        }
        .padding()
        .frame(width: 280)
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
