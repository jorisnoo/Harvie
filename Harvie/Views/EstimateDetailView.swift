//
//  EstimateDetailView.swift
//  Harvie
//

import AppKit
import os.log
import PDFKit
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "EstimateDetail")

struct EstimateDetailView: View {
    let estimate: Estimate
    let creditorInfo: CreditorInfo
    let appSettings: AppSettings
    var onRefresh: (() -> Void)?
    var onStateChanged: ((Int, EstimateState) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingSuccess = false
    @State private var savedFilePath: String?
    @State private var completedAction: CompletedAction?
    @State private var isPerformingAction = false

    private var creditorName: String { creditorInfo.name }

    private let pdfService = PDFService.shared
    private let keychainService = KeychainService.shared
    private let apiService = HarvestAPIService.shared

    private var formattedAmount: String {
        CurrencyFormatter.format(estimate.amount, currency: estimate.currency)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                amountsSection

                if let lineItems = estimate.lineItems, !lineItems.isEmpty {
                    lineItemsSection(lineItems)
                }

                if let notes = estimate.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding()
        }
        .navigationTitle("Estimate \(estimate.number)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await downloadEstimate() }
                } label: {
                    if isProcessing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label(Strings.EstimateDetail.export, systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                .help(Strings.EstimateDetail.exportTooltip)
            }

            if let transition = primaryTransition {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await performTransition(transition) }
                    } label: {
                        Label(transition.label, systemImage: transition.icon)
                    }
                    .disabled(isPerformingAction)
                }
            }

            if estimate.state == .sent {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await performTransition(.decline) }
                    } label: {
                        Label(Strings.EstimateDetail.markAsDeclined, systemImage: "xmark.circle")
                    }
                    .disabled(isPerformingAction)
                }
            }
        }
        .alert(Strings.Common.error, isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(Strings.Common.ok) { error = nil }
        } message: {
            Text(error ?? "")
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
        .alert(item: $completedAction) { action in
            let (title, message) = action.strings(for: estimate.number)
            return Alert(title: Text(title), message: Text(message))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(estimate.subject ?? estimate.number)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                EstimateStateIndicator(state: estimate.state)
            }

            HStack(spacing: 4) {
                Text(estimate.number)
                Text("\u{00B7}")
                Text(estimate.client.name)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedAmount)
                .font(.title)
                .fontWeight(.bold)

            Text(Strings.EstimateDetail.issued(estimate.issueDate.formatted(date: .long, time: .omitted)))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let sentAt = estimate.sentAt {
                Text(Strings.EstimateDetail.sent(sentAt.formatted(date: .long, time: .shortened)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let acceptedAt = estimate.acceptedAt {
                Text(Strings.EstimateDetail.accepted(acceptedAt.formatted(date: .long, time: .shortened)))
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            if let declinedAt = estimate.declinedAt {
                Text(Strings.EstimateDetail.declined(declinedAt.formatted(date: .long, time: .shortened)))
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            if let tax = estimate.tax, let taxAmount = estimate.taxAmount {
                Text(Strings.InvoiceDetail.inclTax(tax.formatted(), CurrencyFormatter.format(taxAmount, currency: estimate.currency)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let discount = estimate.discount, let discountAmount = estimate.discountAmount {
                Text(Strings.InvoiceDetail.discount(discount.formatted(), CurrencyFormatter.format(discountAmount, currency: estimate.currency)))
                    .font(.caption)
            }
        }
    }

    private func lineItemsSection(_ items: [LineItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.vertical, 12)

            ForEach(items) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((item.description ?? "").harvestMarkdown)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 4) {
                            Text(item.quantity.formatted())
                            Text("\u{00D7}")
                            Text(CurrencyFormatter.format(item.unitPrice, currency: estimate.currency))
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(CurrencyFormatter.format(item.amount, currency: estimate.currency))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                if item.id != items.last?.id {
                    Divider()
                }
            }

            Divider().padding(.vertical, 12)
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Strings.EstimateDetail.notes).font(.headline)
            Text(notes.harvestMarkdown)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - State transitions

    private enum Transition {
        case send, accept, decline, reopen

        var label: String {
            switch self {
            case .send: Strings.EstimateDetail.markAsSent
            case .accept: Strings.EstimateDetail.markAsAccepted
            case .decline: Strings.EstimateDetail.markAsDeclined
            case .reopen: Strings.EstimateDetail.reopen
            }
        }

        var icon: String {
            switch self {
            case .send: "paperplane"
            case .accept: "checkmark.circle"
            case .decline: "xmark.circle"
            case .reopen: "arrow.uturn.backward"
            }
        }

        var newState: EstimateState {
            switch self {
            case .send: .sent
            case .accept: .accepted
            case .decline: .declined
            case .reopen: .sent
            }
        }

        var completed: CompletedAction {
            switch self {
            case .send: .markedAsSent
            case .accept: .markedAsAccepted
            case .decline: .markedAsDeclined
            case .reopen: .reopened
            }
        }
    }

    private var primaryTransition: Transition? {
        switch estimate.state {
        case .draft: return .send
        case .sent: return .accept
        case .accepted, .declined: return .reopen
        }
    }

    private func performTransition(_ transition: Transition) async {
        #if DEBUG
        if appSettings.isDemoMode { return }
        #endif

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            let credentials = try await keychainService.loadHarvestCredentials()
            switch transition {
            case .send:
                try await apiService.markEstimateAsSent(estimateId: estimate.id, credentials: credentials)
            case .accept:
                try await apiService.markEstimateAsAccepted(estimateId: estimate.id, credentials: credentials)
            case .decline:
                try await apiService.markEstimateAsDeclined(estimateId: estimate.id, credentials: credentials)
            case .reopen:
                try await apiService.reopenEstimate(estimateId: estimate.id, credentials: credentials)
            }
            completedAction = transition.completed
            onStateChanged?(estimate.id, transition.newState)
        } catch let apiError as HarvestAPIService.APIError {
            self.error = apiError.localizedDescription
        } catch {
            #if DEBUG
            logger.error("State transition failed: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
        }
    }

    // MARK: - Export

    private func downloadEstimate() async {
        isProcessing = true
        error = nil
        savedFilePath = nil
        defer { isProcessing = false }

        do {
            let clientId = estimate.client.id
            let descriptor = FetchDescriptor<ClientOverride>(predicate: #Predicate { $0.clientId == clientId })
            let settings = appSettings.resolved(with: try? modelContext.fetch(descriptor).first)

            let credentials = try await keychainService.loadHarvestCredentials()
            let template: InvoiceTemplate? = settings.effectivePDFSource == .template ? resolveTemplate() : nil

            let pdf: PDFDocument
            if let template {
                pdf = try await pdfService.createEstimateFromTemplate(
                    estimate: estimate,
                    template: template,
                    creditorInfo: creditorInfo,
                    credentials: credentials,
                    language: settings.templateLanguage,
                    labelOverrides: settings.labelOverrides,
                    columnVisibility: settings.columnVisibility
                )
            } else {
                let pdfURL = try HarvestAPIService.shared.buildEstimatePDFURL(for: estimate, subdomain: credentials.subdomain)
                pdf = try await pdfService.downloadPDF(from: pdfURL)
            }

            let fileName = InvoiceFileSaver.sanitizeFilename(settings.generateFilename(
                invoiceNumber: estimate.number,
                creditorName: creditorName,
                clientName: estimate.client.name,
                date: estimate.issueDate,
                issueDate: estimate.issueDate,
                dueDate: estimate.issueDate,
                paidDate: nil
            ))

            let result = try await InvoiceFileSaver.save(pdf, fileName: fileName, settings: settings, pdfService: pdfService)

            switch result {
            case .saved(let path):
                savedFilePath = path
                showingSuccess = true
            case .cancelled:
                break
            }
        } catch let apiError as HarvestAPIService.APIError {
            self.error = apiError.localizedDescription
        } catch let pdfError as PDFService.PDFError {
            self.error = pdfError.localizedDescription
        } catch {
            #if DEBUG
            logger.error("Export failed: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
        }
    }

    private func resolveTemplate() -> InvoiceTemplate? {
        if let templateId = appSettings.selectedTemplateId {
            let descriptor = FetchDescriptor<InvoiceTemplate>(predicate: #Predicate { $0.id == templateId })
            if let template = try? modelContext.fetch(descriptor).first {
                return template
            }
        }
        let fallback = FetchDescriptor<InvoiceTemplate>(sortBy: [SortDescriptor(\.name)])
        return try? modelContext.fetch(fallback).first
    }

    enum CompletedAction: Identifiable {
        case markedAsSent, markedAsAccepted, markedAsDeclined, reopened
        var id: Self { self }

        func strings(for number: String) -> (title: String, message: String) {
            switch self {
            case .markedAsSent: (Strings.EstimateDetail.estimateSent, Strings.EstimateDetail.estimateSentMessage(number))
            case .markedAsAccepted: (Strings.EstimateDetail.estimateAccepted, Strings.EstimateDetail.estimateAcceptedMessage(number))
            case .markedAsDeclined: (Strings.EstimateDetail.estimateDeclined, Strings.EstimateDetail.estimateDeclinedMessage(number))
            case .reopened: (Strings.EstimateDetail.estimateReopened, Strings.EstimateDetail.estimateReopenedMessage(number))
            }
        }
    }
}
