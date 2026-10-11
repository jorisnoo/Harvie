//
//  InvoiceDetailView.swift
//  Harvie
//

import AppKit
import os.log
import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "InvoiceDetail")

struct InvoiceDetailView: View {
    let invoice: Invoice
    let creditorInfo: CreditorInfo
    let appSettings: AppSettings
    var onRefresh: (() -> Void)?
    var onStateChanged: ((Int, InvoiceState) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var model: InvoiceDetailModel
    @State private var isProcessing = false
    @State private var isPreviewing = false
    @State private var showingSuccess = false
    @State private var savedFilePath: String?
    @State private var isSendingEmail = false

    private var creditorName: String { creditorInfo.name }
    private var canExportWithQRBill: Bool { creditorInfo.isValid }

    // Issue date and payment term, edited in the change-date sheet
    private var issueDate = EditableField(Date())
    @State private var paymentTerm: PaymentTerm = .net30
    @State private var paymentDate = Date()

    @FocusState private var focusedField: InvoiceDetailModel.Field?

    // Sheet / action state
    @State private var activeSheet: ActiveSheet?
    @State private var completedAction: CompletedAction?
    @State private var isPerformingSheetAction = false

    private let pdfService = PDFService.shared
    private let keychainService = KeychainService.shared
    private let apiService = HarvestAPIService.shared

    init(
        invoice: Invoice,
        creditorInfo: CreditorInfo,
        appSettings: AppSettings,
        onRefresh: (() -> Void)? = nil,
        onStateChanged: ((Int, InvoiceState) -> Void)? = nil
    ) {
        self.invoice = invoice
        self.creditorInfo = creditorInfo
        self.appSettings = appSettings
        self.onRefresh = onRefresh
        self.onStateChanged = onStateChanged
        _model = State(initialValue: InvoiceDetailModel(
            invoice: invoice, isDemoMode: appSettings.isDemoMode, onRefresh: onRefresh
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InvoiceDetailHeader(
                    invoice: invoice, model: model,
                    focus: $focusedField, isFocused: focusedField == .subject
                )
                InvoiceAmountsSection(invoice: invoice, model: model, onChangeDate: openChangeDate)

                if let lineItems = invoice.lineItems, !lineItems.isEmpty {
                    InvoiceLineItemsSection(
                        items: lineItems, currency: invoice.currency, model: model,
                        focus: $focusedField, focusedField: focusedField
                    )
                }

                InvoiceNotesEditor(model: model, focus: $focusedField, isFocused: focusedField == .notes)
            }
            .padding()
        }
        .onExitCommand { focusedField = nil }
        .onKeyPress(phases: .down) { keyPress in
            guard keyPress.key == .return, keyPress.modifiers.contains(.command) else { return .ignored }
            focusedField = nil
            return .handled
        }
        .onClickOutsideTextFields { [self] in focusedField = nil }
        // Save an edit when its field is left; anything still pending is saved on disappear.
        .onChange(of: focusedField) { previous, _ in
            if let previous { model.save(previous.target) }
        }
        .onAppear { model.viewDidAppear() }
        .onDisappear { model.viewDidDisappear() }
        .navigationTitle(Strings.Detail.invoiceTitle(invoice.number))
        .onChange(of: invoice.id, initial: true) {
            issueDate.reset(to: invoice.issueDate)
            paymentTerm = PaymentTerm.from(issueDate: invoice.issueDate, dueDate: invoice.dueDate)
        }
        .onChange(of: invoice) { model.update(invoice) }
        .onChange(of: invoice.amount) { old, new in
            if new >= 1_000_000, old < 1_000_000 {
                logger.info("💰 THRESHOLD CROSSED — amount=\(new), was=\(old)")
                Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    MoneyRainState.shared.trigger = true
                }
            }
        }
        .toolbar {
            InvoiceDetailToolbar(
                state: invoice.state,
                canExport: canExportWithQRBill,
                isPreviewing: isPreviewing,
                isProcessing: isProcessing,
                isSendingEmail: isSendingEmail,
                isPerformingSheetAction: isPerformingSheetAction,
                perform: handleToolbarAction
            )
        }
        .alert(Strings.Common.error, isPresented: .init(
            get: { model.error != nil },
            set: { if !$0 { model.error = nil } }
        )) {
            Button(Strings.Common.ok) { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
        .alert(Strings.Common.success, isPresented: $showingSuccess) {
            if let path = savedFilePath {
                Button(Strings.InvoiceDetail.showInFinder) {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
            }
            Button(Strings.Common.ok, role: .cancel) { }
        } message: {
            if let path = savedFilePath {
                Text(Strings.InvoiceDetail.savedToPath(path))
            } else {
                Text(Strings.InvoiceDetail.savedSuccessfully)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
        }
        .alert(item: $completedAction) { action in
            let (title, message) = action.strings(for: invoice.number)
            return Alert(title: Text(title), message: Text(message))
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .changeDate:
            ConfirmationSheet(
                title: Strings.InvoiceDetail.changeIssueDate,
                confirmLabel: Strings.Common.save,
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
                    Button(Strings.Common.today) { issueDate.current = Date() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(Calendar.current.isDateInToday(issueDate.current))
                }

                DatePicker(Strings.InvoiceDetail.issueDate, selection: issueDate.binding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                Picker(Strings.InvoiceDetail.dueDate, selection: $paymentTerm) {
                    ForEach(PaymentTerm.pickerCases(including: paymentTerm), id: \.self) { term in
                        Text(term.label).tag(term)
                    }
                }

                Text(Strings.InvoiceDetail.due(
                    paymentTerm.dueDate(from: issueDate.current)
                        .formatted(date: .long, time: .omitted)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        case .markAsSent:
            stateChangeSheet(
                title: Strings.InvoiceDetail.markAsSent,
                message: Strings.InvoiceDetail.markAsSentMessage(invoice.number),
                detail: Strings.InvoiceDetail.sentDateDetail
            ) { await markAsSent() }
        case .markAsDraft:
            stateChangeSheet(
                title: Strings.InvoiceDetail.markAsDraft,
                message: Strings.InvoiceDetail.markAsDraftMessage(invoice.number)
            ) { await markAsDraft() }
        case .markAsPaid:
            ConfirmationSheet(
                title: Strings.InvoiceDetail.markAsPaid,
                message: Strings.InvoiceDetail.markAsPaidMessage(invoice.number),
                confirmLabel: Strings.InvoiceDetail.markAsPaid,
                isProcessing: isPerformingSheetAction,
                onConfirm: { Task { await markAsPaid() } },
                onCancel: { activeSheet = nil },
                width: 300
            ) {
                HStack {
                    Spacer()
                    Button(Strings.Common.today) { paymentDate = Date() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(Calendar.current.isDateInToday(paymentDate))
                }
                DatePicker(Strings.InvoiceDetail.paymentDate, selection: $paymentDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
        case .markAsOpen:
            stateChangeSheet(
                title: Strings.InvoiceDetail.markAsOpen,
                message: Strings.InvoiceDetail.markAsOpenMessage(invoice.number),
                detail: Strings.InvoiceDetail.reopenDetail
            ) { await markAsOpen() }
        case .confirmDateBeforeSend(let action):
            ConfirmationSheet(
                title: Strings.InvoiceDetail.updateIssueDateTitle,
                message: Strings.InvoiceDetail.updateIssueDateMessage(
                    invoice.issueDate.formatted(date: .long, time: .omitted)),
                detail: Strings.InvoiceDetail.keepCurrentDate,
                confirmLabel: Strings.InvoiceDetail.setToToday,
                isProcessing: issueDate.isSaving,
                onConfirm: {
                    Task {
                        issueDate.current = Date()
                        await saveIssueDate()
                        if issueDate.showSaved { activeSheet = nil; performAction(action) }
                    }
                },
                onCancel: { activeSheet = nil; performAction(action) }
            )
        }
    }

    private func stateChangeSheet(
        title: String, message: String, detail: String? = nil,
        action: @escaping () async -> Void
    ) -> some View {
        ConfirmationSheet(
            title: title, message: message, detail: detail, confirmLabel: title,
            isProcessing: isPerformingSheetAction,
            onConfirm: { Task { await action() } },
            onCancel: { activeSheet = nil }
        )
    }

    // MARK: - Actions

    private func handleToolbarAction(_ action: InvoiceDetailToolbar.Action) {
        switch action {
        case .preview: Task { await previewWithQRBill() }
        case .export: Task { await downloadWithQRBill() }
        case .changeDate: openChangeDate()
        case .send(let sendAction): initiateAction(sendAction)
        case .sendViaEmail: Task { await sendViaEmail() }
        case .markAsPaid:
            paymentDate = Date()
            activeSheet = .markAsPaid
        case .markAsDraft: activeSheet = .markAsDraft
        case .markAsOpen: activeSheet = .markAsOpen
        }
    }

    private func performAPIAction(
        label: String,
        action: (HarvestCredentials) async throws -> Void
    ) async -> Bool {
        #if DEBUG
        if appSettings.isDemoMode { return true }
        #endif

        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            try await action(credentials)
            return true
        } catch let apiError as HarvestAPIService.APIError {
            model.error = Strings.InvoiceDetail.failedAction(label, apiError.localizedDescription)
        } catch {
            #if DEBUG
            logger.error("Failed to \(label): \(error.localizedDescription)")
            #endif
            model.error = Strings.InvoiceDetail.failedActionGeneric(label)
        }
        return false
    }

    private func openChangeDate() {
        issueDate.current = invoice.issueDate
        activeSheet = .changeDate
    }

    private func saveIssueDate() async {
        issueDate.markSaving()
        let newDueDate = paymentTerm.dueDate(from: issueDate.current)
        let success = await performAPIAction(label: Strings.Detail.Action.saveIssueDate) { credentials in
            try await apiService.updateInvoiceDates(
                invoiceId: invoice.id, issueDate: issueDate.current, dueDate: newDueDate, credentials: credentials
            )
        }
        if success {
            issueDate.markSaved()
            onRefresh?()
        } else {
            issueDate.markFailed()
        }
    }

    private func initiateAction(_ action: SendAction) {
        guard Calendar.current.isDateInToday(invoice.issueDate) else {
            activeSheet = .confirmDateBeforeSend(action); return
        }
        performAction(action)
    }

    private func performAction(_ action: SendAction) {
        switch action {
        case .sendViaEmail: Task { await sendViaEmail() }
        case .markAsSent: activeSheet = .markAsSent
        }
    }

    private func markAsSent() async {
        await performStateChange(label: Strings.Detail.Action.markAsSent, completed: .markedAsSent, newState: .open) { credentials in
            try await apiService.markInvoiceAsSent(invoiceId: invoice.id, credentials: credentials)
        }
    }

    private func markAsDraft() async {
        await performStateChange(label: Strings.Detail.Action.markAsDraft, completed: .markedAsDraft, newState: .draft) { credentials in
            try await apiService.markInvoiceAsDraft(invoiceId: invoice.id, credentials: credentials)
        }
    }

    private func markAsPaid() async {
        let date = paymentDate
        await performStateChange(label: Strings.Detail.Action.markAsPaid, completed: .markedAsPaid, newState: .paid) { credentials in
            try await apiService.payOutstandingBalance(invoiceId: invoice.id, paidAt: date, credentials: credentials)
        }
    }

    private func markAsOpen() async {
        await performStateChange(label: Strings.Detail.Action.reopenInvoice, completed: .markedAsOpen, newState: .open) { credentials in
            let payments = try await apiService.listPayments(invoiceId: invoice.id, credentials: credentials)
            for payment in payments {
                try await apiService.deletePayment(invoiceId: invoice.id, paymentId: payment.id, credentials: credentials)
            }
        }
    }

    private func performStateChange(
        label: String, completed: CompletedAction, newState: InvoiceState,
        action: (HarvestCredentials) async throws -> Void
    ) async {
        guard !isPerformingSheetAction else { return }
        isPerformingSheetAction = true
        let success = await performAPIAction(label: label, action: action)
        if success { completedAction = completed; activeSheet = nil; onStateChanged?(invoice.id, newState) }
        isPerformingSheetAction = false
    }

    // MARK: - Send via Email

    private func sendViaEmail() async {
        isSendingEmail = true
        model.error = nil

        do {
            let (pdf, _) = try await generatePDF()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(invoiceFileName)
            try await pdfService.savePDF(pdf, to: tempURL)

            // Fetch client contact emails
            var recipientEmails: [String] = []
            if let credentials = try? await keychainService.loadHarvestCredentials() {
                let contacts = try? await apiService.fetchClientContacts(
                    clientId: invoice.client.id, credentials: credentials
                )
                recipientEmails = contacts?.compactMap(\.email).filter { !$0.isEmpty } ?? []
            }

            // Compose email via NSSharingService
            guard let emailService = NSSharingService(named: .composeEmail) else {
                model.error = Strings.InvoiceDetail.emailNotConfigured
                isSendingEmail = false
                return
            }

            emailService.recipients = recipientEmails
            let emailSettings = TemplateResolver(context: modelContext).settings(appSettings, forClient: invoice.client.id)
            emailService.subject = emailSettings.generateEmailSubject(
                invoiceLabel: emailSettings.templateLanguage.labels["invoice"]!,
                invoiceNumber: invoice.number,
                title: invoice.subject,
                clientName: invoice.client.name,
                creditorName: creditorName
            )
            emailService.perform(withItems: [tempURL])

            // The mail composer does not confirm delivery. Marking as sent remains
            // an explicit action so cancelling a draft never changes Harvest.

        } catch {
            handlePDFError(error, context: "Send via email")
        }

        isSendingEmail = false
    }
}

// MARK: - PDF Generation

private extension InvoiceDetailView {
    func generatePDF() async throws -> (pdf: PDFDocument, settings: AppSettings) {
        let resolver = TemplateResolver(context: modelContext)
        let settings = resolver.settings(appSettings, forClient: invoice.client.id)

        #if DEBUG
        let effectiveCreditorInfo = creditorInfo.isValid ? creditorInfo : DemoDataProvider.defaultCreditorInfo
        #else
        let effectiveCreditorInfo = creditorInfo
        #endif

        guard effectiveCreditorInfo.isValid else {
            throw GenerationError.invalidCreditor
        }

        if settings.effectivePDFSource == .template {
            guard let template = resolver.template(for: settings) else {
                throw GenerationError.templateNotFound
            }
            let credentials = try? await keychainService.loadHarvestCredentials()
            let pdf = try await pdfService.createInvoiceFromTemplate(
                invoice: invoice,
                template: template,
                creditorInfo: effectiveCreditorInfo,
                credentials: credentials,
                language: settings.templateLanguage,
                labelOverrides: settings.labelOverrides,
                paidMarkStyle: settings.paidMarkStyle,
                columnVisibility: settings.columnVisibility
            )
            return (pdf, settings)
        }

        #if DEBUG
        if settings.isDemoMode {
            let pdf = try await pdfService.createDemoInvoiceWithQRBill(
                invoice: invoice, creditorInfo: effectiveCreditorInfo,
                paidMarkStyle: settings.paidMarkStyle
            )
            return (pdf, settings)
        }
        #endif

        let credentials = try await keychainService.loadHarvestCredentials()
        let pdf = try await pdfService.createInvoiceWithQRBill(
            invoice: invoice, credentials: credentials, creditorInfo: effectiveCreditorInfo,
            language: settings.templateLanguage,
            labelOverrides: settings.labelOverrides,
            paidMarkStyle: settings.paidMarkStyle
        )
        return (pdf, settings)
    }

    func previewWithQRBill() async {
        isPreviewing = true
        model.error = nil

        do {
            let (pdf, _) = try await generatePDF()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(invoiceFileName)
            try await pdfService.savePDF(pdf, to: tempURL)
            NSWorkspace.shared.open(tempURL)
            Analytics.pdfPreviewed()
        } catch {
            handlePDFError(error, context: "Preview")
        }

        isPreviewing = false
    }

    func downloadWithQRBill() async {
        isProcessing = true
        model.error = nil
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

    func handlePDFError(_ error: Error, context: String) {
        if let apiError = error as? HarvestAPIService.APIError {
            model.error = apiError.localizedDescription
        } else if let pdfError = error as? PDFService.PDFError {
            model.error = pdfError.localizedDescription
        } else {
            #if DEBUG
            logger.error("\(context) failed: \(error.localizedDescription)")
            #endif
            model.error = error.localizedDescription
        }
    }

    var invoiceFileName: String {
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

    enum GenerationError: LocalizedError {
        case invalidCreditor
        case templateNotFound

        var errorDescription: String? {
            switch self {
            case .invalidCreditor: Strings.Errors.configureCreditor
            case .templateNotFound: Strings.Errors.noTemplateSelected
            }
        }
    }
}

// MARK: - Sheets and Actions

extension InvoiceDetailView {
    enum ActiveSheet: Identifiable {
        case changeDate, markAsSent, markAsDraft, markAsPaid, markAsOpen, confirmDateBeforeSend(SendAction)
        var id: String {
            switch self {
            case .changeDate: "changeDate"
            case .markAsSent: "markAsSent"
            case .markAsDraft: "markAsDraft"
            case .markAsPaid: "markAsPaid"
            case .markAsOpen: "markAsOpen"
            case .confirmDateBeforeSend: "confirmDateBeforeSend"
            }
        }
    }

    enum SendAction {
        case sendViaEmail, markAsSent
    }

    enum CompletedAction: Identifiable {
        case markedAsSent, markedAsDraft, markedAsPaid, markedAsOpen
        var id: Self { self }

        func strings(for number: String) -> (title: String, message: String) {
            switch self {
            case .markedAsSent: (Strings.InvoiceDetail.invoiceSent, Strings.InvoiceDetail.invoiceSentMessage(number))
            case .markedAsDraft: (Strings.InvoiceDetail.invoiceReverted, Strings.InvoiceDetail.invoiceRevertedMessage(number))
            case .markedAsPaid: (Strings.InvoiceDetail.invoiceMarkedPaid, Strings.InvoiceDetail.invoiceMarkedPaidMessage(number))
            case .markedAsOpen: (Strings.InvoiceDetail.invoiceReopened, Strings.InvoiceDetail.invoiceReopenedMessage(number))
            }
        }
    }
}
