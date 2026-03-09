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
    let creditorInfo: CreditorInfo
    let appSettings: AppSettings
    var onRefresh: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var isProcessing = false
    @State private var isPreviewing = false
    @State private var error: String?
    @State private var showingSuccess = false
    @State private var savedFilePath: String?

    private var creditorName: String { creditorInfo.name }
    private var canExportWithQRBill: Bool { creditorInfo.isValid }

    // Editable fields
    var subject = EditableField("")
    var notes = EditableField("")
    var issueDate = EditableField(Date())

    // Line item editing
    @State private var editedDescriptions: [Int: String] = [:]
    @State private var editedUnitPrices: [Int: String] = [:]
    @State private var savingLineItems: Set<Int> = []
    @State private var savedLineItems: Set<Int> = []
    @State private var savedTimers: [Int: Task<Void, Never>] = [:]

    // Focus
    @FocusState private var focusedField: FocusedField?

    // Sheet / action state
    @State private var activeSheet: ActiveSheet?
    @State private var completedAction: CompletedAction?
    @State private var isPerformingSheetAction = false

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
        .onExitCommand { focusedField = nil }
        .onClickOutsideTextFields { [self] in focusedField = nil }
        .navigationTitle("Invoice \(invoice.number)")
        .onChange(of: invoice.id, initial: true) {
            subject.reset(to: invoice.subject ?? "")
            notes.reset(to: invoice.notes ?? "")
            issueDate.reset(to: invoice.issueDate)
            editedDescriptions = [:]
            editedUnitPrices = [:]
            savingLineItems = []
            savedLineItems = []
            savedTimers.values.forEach { $0.cancel() }
            savedTimers = [:]
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
                            activeSheet = .markAsSent
                        } label: {
                            Label("Mark as Sent", systemImage: "paperplane")
                        }
                        .disabled(isPerformingSheetAction)

                        Button {
                            issueDate.current = invoice.issueDate
                            activeSheet = .changeDate
                        } label: {
                            Label("Change Date", systemImage: "calendar")
                        }
                    }

                    if invoice.state == .open {
                        Button {
                            activeSheet = .markAsDraft
                        } label: {
                            Label("Mark as Draft", systemImage: "pencil")
                        }
                        .disabled(isPerformingSheetAction)
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .changeDate:
                ConfirmationSheet(
                    title: "Change Issue Date",
                    confirmLabel: "Save",
                    isProcessing: issueDate.isSaving,
                    onConfirm: {
                        Task {
                            await saveIssueDate()
                            if issueDate.showSaved { activeSheet = nil }
                        }
                    },
                    onCancel: { activeSheet = nil },
                    width: 300
                ) {
                    HStack {
                        Spacer()
                        Button("Today") { issueDate.current = Date() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(Calendar.current.isDateInToday(issueDate.current))
                    }

                    DatePicker("Issue Date", selection: issueDate.binding, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
            case .markAsSent:
                ConfirmationSheet(
                    title: "Mark as Sent",
                    message: "Mark invoice \(invoice.number) as sent?",
                    detail: "The sent date will be set to now.",
                    confirmLabel: "Mark as Sent",
                    isProcessing: isPerformingSheetAction,
                    onConfirm: {
                        Task {
                            await markAsSent()
                            if completedAction == .markedAsSent { activeSheet = nil }
                        }
                    },
                    onCancel: { activeSheet = nil }
                )
            case .markAsDraft:
                ConfirmationSheet(
                    title: "Mark as Draft",
                    message: "Revert invoice \(invoice.number) to draft?",
                    confirmLabel: "Mark as Draft",
                    isProcessing: isPerformingSheetAction,
                    onConfirm: {
                        Task {
                            await markAsDraft()
                            if completedAction == .markedAsDraft { activeSheet = nil }
                        }
                    },
                    onCancel: { activeSheet = nil }
                )
            }
        }
        .alert(item: $completedAction) { action in
            switch action {
            case .markedAsSent:
                Alert(
                    title: Text("Invoice Sent"),
                    message: Text("Invoice \(invoice.number) has been marked as sent.")
                )
            case .markedAsDraft:
                Alert(
                    title: Text("Invoice Reverted"),
                    message: Text("Invoice \(invoice.number) has been reverted to draft.")
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Invoice title", text: subject.binding)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .subject)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(focusedField == .subject ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                    )

                if subject.isModified {
                    if subject.showSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Button {
                        Task { await saveSubject() }
                    } label: {
                        if subject.isSaving {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(subject.isSaving)
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
    }

    // MARK: - Amounts

    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(invoice.state == .paid ? formattedAmount : formattedDueAmount)
                .font(.title)
                .fontWeight(.bold)

            if invoice.state != .paid, invoice.dueAmount != invoice.amount {
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
                        HStack {
                            TextField("Description", text: descriptionBinding(for: item), axis: .vertical)
                                .font(.body)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .lineItem(item.id))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(focusedField == .lineItem(item.id) ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                                )
                                .padding(.leading, -6)
                                .onSubmit {
                                    // Insert newline instead of submitting
                                    let binding = descriptionBinding(for: item)
                                    binding.wrappedValue += "\n"
                                }
                                .overlay {
                                    if focusedField != .lineItem(item.id) {
                                        Text(descriptionBinding(for: item).wrappedValue.harvestMarkdown)
                                            .font(.body)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 4)
                                            .background(.background)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .onChange(of: focusedField) {
                                    if focusedField != .lineItem(item.id), isLineItemModified(item) {
                                        Task { await saveLineItem(item) }
                                    }
                                }

                            if savingLineItems.contains(item.id) {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else if savedLineItems.contains(item.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack(spacing: 2) {
                            Text("\(item.quantity.formatted()) ×")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            TextField(
                                "Price",
                                text: unitPriceBinding(for: item)
                            )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .unitPrice(item.id))
                            .fixedSize()
                            .onSubmit { focusedField = nil }
                            .onChange(of: focusedField) {
                                if focusedField != .unitPrice(item.id), isUnitPriceModified(item) {
                                    Task { await saveLineItem(item) }
                                }
                            }
                        }
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

            TextEditor(text: notes.binding)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .notes)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(focusedField == .notes ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                )
                .padding(.leading, -4)
                .overlay {
                    if focusedField != .notes {
                        Text(notes.current.harvestMarkdown)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
                            .padding(4)
                            .background(.background)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: focusedField) {
                    if focusedField != .notes, notes.isModified {
                        Task { await saveNotes() }
                    }
                }

            if notes.isSaving {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                }
            } else if notes.showSaved {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
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
        subject.markSaving()
        let success = await performAPIAction(label: "save title") { credentials in
            try await apiService.updateInvoiceSubject(
                invoiceId: invoice.id, subject: subject.current, credentials: credentials
            )
        }
        if success { subject.markSaved() } else { subject.markFailed() }
    }

    private func saveNotes() async {
        notes.markSaving()
        let success = await performAPIAction(label: "save notes") { credentials in
            try await apiService.updateInvoiceNotes(
                invoiceId: invoice.id, notes: notes.current, credentials: credentials
            )
        }
        if success { notes.markSaved(); onRefresh?() } else { notes.markFailed() }
    }

    // MARK: - Line Item Editing

    private func descriptionBinding(for item: LineItem) -> Binding<String> {
        Binding(
            get: { editedDescriptions[item.id] ?? item.description ?? "" },
            set: { newValue in
                editedDescriptions[item.id] = newValue
                savedLineItems.remove(item.id)
            }
        )
    }

    private func isLineItemModified(_ item: LineItem) -> Bool {
        if let edited = editedDescriptions[item.id], edited != (item.description ?? "") {
            return true
        }
        return isUnitPriceModified(item)
    }

    private func unitPriceBinding(for item: LineItem) -> Binding<String> {
        Binding(
            get: { editedUnitPrices[item.id] ?? item.unitPrice.formatted() },
            set: { newValue in
                // Allow only digits, dots, and commas
                let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                editedUnitPrices[item.id] = filtered
                savedLineItems.remove(item.id)
            }
        )
    }

    private func isUnitPriceModified(_ item: LineItem) -> Bool {
        guard let edited = editedUnitPrices[item.id] else { return false }
        return edited != item.unitPrice.formatted()
    }

    private func parsePrice(_ string: String) -> Decimal? {
        let cleaned = string.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
        // Handle both comma and dot as decimal separator
        let normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private func saveLineItem(_ item: LineItem) async {
        let editedDescription = editedDescriptions[item.id]
        let editedPrice = editedUnitPrices[item.id].flatMap { parsePrice($0) }
        guard editedDescription != nil || editedPrice != nil else { return }
        savingLineItems.insert(item.id)
        let success = await performAPIAction(label: "save line item") { credentials in
            try await apiService.updateLineItem(
                invoiceId: invoice.id, lineItemId: item.id,
                description: editedDescription,
                unitPrice: editedPrice,
                allLineItems: invoice.lineItems ?? [],
                credentials: credentials
            )
        }
        savingLineItems.remove(item.id)
        if success {
            editedDescriptions.removeValue(forKey: item.id)
            editedUnitPrices.removeValue(forKey: item.id)
            savedLineItems.insert(item.id)
            savedTimers[item.id]?.cancel()
            savedTimers[item.id] = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                savedLineItems.remove(item.id)
            }
            onRefresh?()
        }
    }

    private func saveIssueDate() async {
        issueDate.markSaving()
        let success = await performAPIAction(label: "save issue date") { credentials in
            try await apiService.updateInvoiceIssueDate(
                invoiceId: invoice.id, issueDate: issueDate.current, credentials: credentials
            )
        }
        if success {
            issueDate.markSaved()
            onRefresh?()
        } else {
            issueDate.markFailed()
        }
    }

    private func markAsSent() async {
        isPerformingSheetAction = true
        let success = await performAPIAction(label: "mark as sent") { credentials in
            try await apiService.markInvoiceAsSent(invoiceId: invoice.id, credentials: credentials)
        }
        if success {
            completedAction = .markedAsSent
            onRefresh?()
        }
        isPerformingSheetAction = false
    }

    private func markAsDraft() async {
        isPerformingSheetAction = true
        let success = await performAPIAction(label: "mark as draft") { credentials in
            try await apiService.markInvoiceAsDraft(invoiceId: invoice.id, credentials: credentials)
        }
        if success {
            completedAction = .markedAsDraft
            onRefresh?()
        }
        isPerformingSheetAction = false
    }

    // MARK: - PDF Generation

    private func generatePDF() async throws -> (pdf: PDFDocument, settings: AppSettings) {
        #if DEBUG
        let effectiveCreditorInfo = creditorInfo.isValid ? creditorInfo : DemoDataProvider.defaultCreditorInfo
        #else
        let effectiveCreditorInfo = creditorInfo
        #endif

        guard effectiveCreditorInfo.isValid else {
            throw GenerationError.invalidCreditor
        }

        if appSettings.effectivePDFSource == .template {
            guard let templateId = appSettings.selectedTemplateId,
                  let template = loadTemplate(id: templateId) else {
                throw GenerationError.templateNotFound
            }
            let credentials = try? await keychainService.loadHarvestCredentials()
            let pdf = try await pdfService.createInvoiceFromTemplate(
                invoice: invoice,
                template: template,
                creditorInfo: effectiveCreditorInfo,
                credentials: credentials,
                language: appSettings.templateLanguage,
                labelOverrides: appSettings.labelOverrides,
                paidMarkStyle: appSettings.paidMarkStyle
            )
            return (pdf, appSettings)
        }

        #if DEBUG
        if appSettings.isDemoMode {
            let pdf = try await pdfService.createDemoInvoiceWithQRBill(
                invoice: invoice, creditorInfo: effectiveCreditorInfo,
                paidMarkStyle: appSettings.paidMarkStyle
            )
            return (pdf, appSettings)
        }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        let pdf = try await pdfService.createInvoiceWithQRBill(
            invoice: invoice, credentials: credentials, creditorInfo: effectiveCreditorInfo,
            language: appSettings.templateLanguage,
            labelOverrides: appSettings.labelOverrides,
            paidMarkStyle: appSettings.paidMarkStyle
        )
        return (pdf, appSettings)
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
            paidDate: invoice.effectivePaidDate
        )
        return InvoiceFileSaver.sanitizeFilename(rawFilename)
    }

    private enum GenerationError: LocalizedError {
        case invalidCreditor
        case templateNotFound

        var errorDescription: String? {
            switch self {
            case .invalidCreditor:
                "Please configure your creditor information in Settings."
            case .templateNotFound:
                "No template selected. Please select a template in Settings > Templates."
            }
        }
    }

    private enum FocusedField: Hashable {
        case subject, notes, lineItem(Int), unitPrice(Int)
    }

    private enum ActiveSheet: Identifiable {
        case changeDate, markAsSent, markAsDraft
        var id: Self { self }
    }

    private enum CompletedAction: Identifiable {
        case markedAsSent, markedAsDraft
        var id: Self { self }
    }
}

private extension String {
    /// Renders Harvest-flavored markdown as an `AttributedString`.
    /// Harvest treats both `*text*` and `**text**` as bold; `- item` as list bullets.
    var harvestMarkdown: AttributedString {
        // Normalize line endings, then convert list markers to bullet points
        let normalized = self
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let preprocessed = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.drop(while: { $0 == " " })
                if trimmed.hasPrefix("- ") {
                    return "• " + trimmed.dropFirst(2)
                }
                return String(line)
            }
            .joined(separator: "\n")

        var result = (try? AttributedString(
            markdown: preprocessed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(preprocessed)

        // Harvest: both *text* and **text** render as bold only (no italic)
        for run in result.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.stronglyEmphasized) || intent.contains(.emphasized) {
                result[run.range].font = Font.body.bold()
                result[run.range].inlinePresentationIntent = .stronglyEmphasized
            }
        }

        return result
    }
}

private struct ClickOutsideTextFieldsModifier: ViewModifier {
    let action: () -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                    guard let contentView = event.window?.contentView else { return event }
                    let location = contentView.convert(event.locationInWindow, from: nil)
                    let hitView = contentView.hitTest(location)
                    if !(hitView is NSTextField || hitView is NSTextView) {
                        action()
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

extension View {
    func onClickOutsideTextFields(perform action: @escaping () -> Void) -> some View {
        modifier(ClickOutsideTextFieldsModifier(action: action))
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
    ), creditorInfo: .empty, appSettings: .default)
}
