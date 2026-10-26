//
//  InvoiceDetailModel.swift
//  Harvie
//

import Accessibility
import Foundation
import Observation
import os.log
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "InvoiceDetail")

extension Notification.Name {
    /// Posted when an inline edit fails to save after its detail view has gone.
    /// `userInfo["message"]` holds the user-facing error message.
    static let detailSaveFailed = Notification.Name("DetailSaveFailed")
}

/// An inline edit sent to Harvest.
enum InvoiceEdit: Sendable {
    case subject(String)
    case notes(String)
    case lineItem(id: Int, description: String, quantity: Decimal?, unitPrice: Decimal?, allLineItems: [LineItem])
}

/// The editable values of a line item.
struct LineItemValues: Equatable, Sendable {
    var description: String
    var quantity: Decimal
    var unitPrice: Decimal

    init(description: String, quantity: Decimal, unitPrice: Decimal) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
    }

    init(_ item: LineItem) {
        self.init(description: item.description ?? "", quantity: item.quantity, unitPrice: item.unitPrice)
    }
}

/// Inline edits of one invoice. Saves run one after another in tasks that outlive the
/// detail view, so edits made just before switching invoices still reach Harvest.
@MainActor
@Observable
final class InvoiceDetailModel {
    enum Field: Hashable {
        case subject, notes, lineItem(Int), quantity(Int), unitPrice(Int)

        var target: Target {
            switch self {
            case .subject: .subject
            case .notes: .notes
            case .lineItem(let id), .quantity(let id), .unitPrice(let id): .lineItem(id)
            }
        }
    }

    /// What is saved as a unit; a line item's fields share one save.
    enum Target: Hashable {
        case subject, notes, lineItem(Int)
    }

    typealias Sender = @MainActor (InvoiceEdit) async throws -> Void

    private(set) var invoice: Invoice
    var error: String?

    private(set) var subject: String
    private(set) var notes: String
    private var savedSubject: String
    private var savedNotes: String
    private var descriptions: [Int: String] = [:]
    private var quantities: [Int: String] = [:]
    private var unitPrices: [Int: String] = [:]
    /// Line item values Harvest accepted that `invoice` may not reflect yet.
    private var confirmed: [Int: LineItemValues] = [:]

    private var pendingSaves: [Target: Int] = [:]
    private var savedTargets: Set<Target> = []

    private let send: Sender
    private let onRefresh: (() -> Void)?
    @ObservationIgnored private var queue: Task<Void, Never>?
    @ObservationIgnored private var hideSavedTasks: [Target: Task<Void, Never>] = [:]
    @ObservationIgnored private var isPresented = true

    init(invoice: Invoice, onRefresh: (() -> Void)? = nil, send: @escaping Sender) {
        self.invoice = invoice
        self.onRefresh = onRefresh
        self.send = send
        subject = invoice.subject ?? ""
        savedSubject = invoice.subject ?? ""
        notes = invoice.notes ?? ""
        savedNotes = invoice.notes ?? ""
    }

    convenience init(invoice: Invoice, isDemoMode: Bool, onRefresh: (() -> Void)?) {
        #if DEBUG
        let skipsHarvest = isDemoMode
        #else
        let skipsHarvest = false
        #endif
        let invoiceId = invoice.id
        self.init(invoice: invoice, onRefresh: onRefresh) { edit in
            guard !skipsHarvest else { return }
            try await InvoiceDetailModel.sendToHarvest(edit, invoiceId: invoiceId)
        }
    }

    private static func sendToHarvest(_ edit: InvoiceEdit, invoiceId: Int) async throws {
        let credentials = try await KeychainService.shared.loadHarvestCredentials()
        let api = HarvestAPIService.shared
        switch edit {
        case .subject(let subject):
            try await api.updateInvoiceSubject(invoiceId: invoiceId, subject: subject, credentials: credentials)
        case .notes(let notes):
            try await api.updateInvoiceNotes(invoiceId: invoiceId, notes: notes, credentials: credentials)
        case let .lineItem(id, description, quantity, unitPrice, allLineItems):
            try await api.updateLineItem(
                invoiceId: invoiceId, lineItemId: id,
                description: description, quantity: quantity, unitPrice: unitPrice,
                allLineItems: allLineItems, credentials: credentials
            )
        }
    }

    // MARK: - View lifecycle

    func update(_ invoice: Invoice) {
        self.invoice = invoice
        // Forget confirmations the fetched invoice already reflects.
        for item in invoice.lineItems ?? [] where confirmed[item.id] == LineItemValues(item) {
            confirmed[item.id] = nil
        }
    }

    func viewDidAppear() {
        isPresented = true
    }

    /// Saves every pending edit; failures are then reported via `.detailSaveFailed`.
    func viewDidDisappear() {
        isPresented = false
        save(.subject)
        save(.notes)
        for id in Set(descriptions.keys).union(quantities.keys).union(unitPrices.keys).sorted() {
            save(.lineItem(id))
        }
    }

    // MARK: - Editing

    func text(for field: Field) -> String {
        switch field {
        case .subject: subject
        case .notes: notes
        case .lineItem(let id): descriptions[id] ?? knownValues(for: id)?.description ?? ""
        case .quantity(let id): quantities[id] ?? knownValues(for: id)?.quantity.formatted() ?? ""
        case .unitPrice(let id): unitPrices[id] ?? knownValues(for: id)?.unitPrice.formatted() ?? ""
        }
    }

    func setText(_ text: String, for field: Field) {
        switch field {
        case .subject: subject = text
        case .notes: notes = text
        case .lineItem(let id): descriptions[id] = text
        case .quantity(let id): quantities[id] = text
        case .unitPrice(let id): unitPrices[id] = text
        }
        hideSaved(field.target)
    }

    func binding(for field: Field) -> Binding<String> {
        Binding(
            get: { self.text(for: field) },
            set: { self.setText($0, for: field) }
        )
    }

    func isModified(_ target: Target) -> Bool {
        switch target {
        case .subject: return subject != savedSubject
        case .notes: return notes != savedNotes
        case .lineItem(let id):
            guard let known = knownValues(for: id) else { return false }
            return pendingValues(for: id) != known
        }
    }

    func isSaving(_ target: Target) -> Bool { pendingSaves[target] != nil }
    func showsSaved(_ target: Target) -> Bool { savedTargets.contains(target) }

    // MARK: - Live amounts

    /// The line item's amount including unsaved quantity and price edits.
    func lineAmount(for item: LineItem) -> Decimal {
        let (quantity, unitPrice) = liveQuantityAndPrice(for: item)
        guard quantity != item.quantity || unitPrice != item.unitPrice else { return item.amount }
        return rounded(quantity * unitPrice)
    }

    var liveAmount: Decimal {
        guard let lineItems = invoice.lineItems, isRepriced else { return invoice.amount }

        var subtotal: Decimal = 0
        var taxableAmount: Decimal = 0
        var taxable2Amount: Decimal = 0

        for item in lineItems {
            let amount = lineAmount(for: item)
            subtotal += amount
            if item.taxed { taxableAmount += amount }
            if item.taxed2 { taxable2Amount += amount }
        }

        let tax = rounded((invoice.tax ?? 0) * taxableAmount / 100)
        let tax2 = rounded((invoice.tax2 ?? 0) * taxable2Amount / 100)
        let discount = rounded((invoice.discount ?? 0) * subtotal / 100)

        return rounded(subtotal + tax + tax2 - discount)
    }

    var liveDueAmount: Decimal {
        rounded(invoice.dueAmount + (liveAmount - invoice.amount))
    }

    var liveTaxAmount: Decimal {
        guard let lineItems = invoice.lineItems, let taxRate = invoice.tax, isRepriced else {
            return invoice.taxAmount ?? 0
        }
        let taxable = lineItems.reduce(Decimal.zero) { total, item in
            item.taxed ? total + lineAmount(for: item) : total
        }
        return rounded(taxable * taxRate / 100)
    }

    var liveDiscountAmount: Decimal {
        guard let lineItems = invoice.lineItems, let discountRate = invoice.discount, isRepriced else {
            return invoice.discountAmount ?? 0
        }
        let subtotal = lineItems.reduce(Decimal.zero) { total, item in
            total + lineAmount(for: item)
        }
        return rounded(subtotal * discountRate / 100)
    }

    private var isRepriced: Bool {
        invoice.lineItems?.contains { item in
            let (quantity, unitPrice) = liveQuantityAndPrice(for: item)
            return quantity != item.quantity || unitPrice != item.unitPrice
        } ?? false
    }

    private func liveQuantityAndPrice(for item: LineItem) -> (Decimal, Decimal) {
        let known = confirmed[item.id]
        let quantity = quantities[item.id].flatMap { DecimalInput.parse($0) } ?? known?.quantity ?? item.quantity
        let unitPrice = unitPrices[item.id].flatMap { DecimalInput.parse($0) } ?? known?.unitPrice ?? item.unitPrice
        return (quantity, unitPrice)
    }

    private func rounded(_ value: Decimal) -> Decimal {
        CurrencyFormatter.rounded(value, currency: invoice.currency)
    }

    // MARK: - Saving

    /// Saves the target if it has unsaved edits. Saves for this invoice run in order.
    func save(_ target: Target) {
        guard isModified(target) else { return }
        switch target {
        case .subject:
            enqueue(target) { [self] in
                let value = subject
                guard value != savedSubject,
                      await perform(.subject(value), action: Strings.Detail.Action.saveTitle) else { return }
                savedSubject = value
                didSave(target)
            }
        case .notes:
            enqueue(target) { [self] in
                let value = notes
                guard value != savedNotes,
                      await perform(.notes(value), action: Strings.Detail.Action.saveNotes) else { return }
                savedNotes = value
                didSave(target)
            }
        case .lineItem(let id):
            guard pendingValues(for: id) != nil else {
                report(Strings.Detail.invalidNumber)
                return
            }
            enqueue(target) { [self] in await saveLineItem(id) }
        }
    }

    /// Waits until every queued save has finished.
    func waitForSaves() async {
        while let current = queue {
            await current.value
            if queue == current { return }
        }
    }

    private func saveLineItem(_ id: Int) async {
        // Read the edits now, not when the save was queued, so the latest text is sent.
        guard let known = knownValues(for: id), let values = pendingValues(for: id), values != known else { return }
        let sentDescription = descriptions[id]
        // Send the latest known values of the other items so this save doesn't revert them.
        let lineItems = (invoice.lineItems ?? []).map { item in
            confirmed[item.id].map { item.replacing($0) } ?? item
        }
        let edit = InvoiceEdit.lineItem(
            id: id,
            description: values.description,
            quantity: values.quantity == known.quantity ? nil : values.quantity,
            unitPrice: values.unitPrice == known.unitPrice ? nil : values.unitPrice,
            allLineItems: lineItems
        )
        guard await perform(edit, action: Strings.Detail.Action.saveLineItem) else { return }

        confirmed[id] = values
        // Keep text typed while the save was in flight; it is saved when its field is left.
        // Quantity and price text stays as typed and now matches the confirmed values.
        if descriptions[id] == sentDescription { descriptions[id] = nil }
        didSave(.lineItem(id))
    }

    private func enqueue(_ target: Target, _ operation: @escaping @MainActor () async -> Void) {
        pendingSaves[target, default: 0] += 1
        hideSaved(target)
        let previous = queue
        queue = Task { [self] in
            await previous?.value
            await operation()
            let remaining = (pendingSaves[target] ?? 1) - 1
            pendingSaves[target] = remaining > 0 ? remaining : nil
        }
    }

    private func perform(_ edit: InvoiceEdit, action: String) async -> Bool {
        do {
            try await send(edit)
            return true
        } catch let apiError as HarvestAPIService.APIError {
            report(Strings.InvoiceDetail.failedAction(action, apiError.localizedDescription))
        } catch {
            #if DEBUG
            logger.error("Failed to \(action): \(error.localizedDescription)")
            #endif
            report(Strings.InvoiceDetail.failedActionGeneric(action))
        }
        return false
    }

    /// Shows the error in the detail view, or app-wide once the view has gone.
    private func report(_ message: String) {
        if isPresented {
            error = message
        } else {
            NotificationCenter.default.post(name: .detailSaveFailed, object: nil, userInfo: ["message": message])
        }
    }

    private func didSave(_ target: Target) {
        if !isModified(target) {
            savedTargets.insert(target)
            if isPresented {
                AccessibilityNotification.Announcement(Strings.Detail.saved).post()
            }
            hideSavedTasks[target]?.cancel()
            hideSavedTasks[target] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.savedTargets.remove(target)
            }
        }
        onRefresh?()
    }

    private func hideSaved(_ target: Target) {
        hideSavedTasks[target]?.cancel()
        hideSavedTasks[target] = nil
        savedTargets.remove(target)
    }

    // MARK: - Line item values

    /// The values Harvest holds, as far as we know.
    private func knownValues(for id: Int) -> LineItemValues? {
        if let values = confirmed[id] { return values }
        return invoice.lineItems?.first(where: { $0.id == id }).map { LineItemValues($0) }
    }

    /// The values including edits, or `nil` if a number can't be parsed.
    private func pendingValues(for id: Int) -> LineItemValues? {
        guard let known = knownValues(for: id),
              let quantity = parsed(quantities[id], default: known.quantity),
              let unitPrice = parsed(unitPrices[id], default: known.unitPrice) else { return nil }
        return LineItemValues(description: descriptions[id] ?? known.description, quantity: quantity, unitPrice: unitPrice)
    }

    private func parsed(_ text: String?, default value: Decimal) -> Decimal? {
        guard let text else { return value }
        return DecimalInput.parse(text)
    }
}

private extension LineItem {
    func replacing(_ values: LineItemValues) -> LineItem {
        LineItem(
            id: id, kind: kind, description: values.description,
            quantity: values.quantity, unitPrice: values.unitPrice, amount: amount,
            taxed: taxed, taxed2: taxed2, project: project
        )
    }
}
