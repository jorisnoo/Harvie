//
//  InvoiceDetailModelTests.swift
//  HarvieTests
//

import Foundation
import Testing
@testable import Harvie

@Suite("Invoice detail inline edits")
@MainActor
struct InvoiceDetailModelTests {
    private func invoice(subject: String? = nil, notes: String? = nil) -> Invoice {
        let date = Date(timeIntervalSince1970: 1_788_220_800)
        let items = [1, 2].map { id in
            LineItem(id: id, kind: "Service", description: "Item \(id)", quantity: 1, unitPrice: 50,
                     amount: 50, taxed: false, taxed2: false, project: nil)
        }
        return Invoice(id: 7, clientKey: "fixture", number: "INV-7", amount: 100, dueAmount: 100,
                       subject: subject, notes: notes, currency: "CHF", state: .draft, issueDate: date, dueDate: date,
                       createdAt: date, updatedAt: date, client: ClientReference(id: 1, name: "Fixture"),
                       lineItems: items)
    }

    @Test func savingTitleRefreshesInvoice() async {
        let recorder = EditRecorder()
        var refreshes = 0
        let model = InvoiceDetailModel(invoice: invoice(), onRefresh: { refreshes += 1 }) { try await recorder.send($0) }

        model.setText("New title", for: .subject)
        model.save(.subject)
        await model.waitForSaves()

        #expect(recorder.subjects == ["New title"])
        #expect(refreshes == 1)
        #expect(!model.isModified(.subject))
        #expect(model.showsSaved(.subject))
    }

    @Test func refreshedInvoiceUpdatesUneditedTextOnly() {
        let model = InvoiceDetailModel(invoice: invoice(subject: "Old", notes: "Old notes")) { _ in }

        model.setText("Typing", for: .notes)
        model.update(invoice(subject: "Fetched", notes: "Fetched notes"))

        #expect(model.text(for: .subject) == "Fetched")
        #expect(!model.isModified(.subject))
        #expect(model.text(for: .notes) == "Typing")
    }

    @Test func editsMadeDuringASaveAreKeptAndSavedInOrder() async {
        let recorder = EditRecorder()
        recorder.holdsNextSend = true
        let model = InvoiceDetailModel(invoice: invoice()) { try await recorder.send($0) }

        model.setText("First", for: .lineItem(1))
        model.save(.lineItem(1))
        while recorder.edits.isEmpty { await Task.yield() }

        // Typed while the first save is in flight.
        model.setText("Second", for: .lineItem(1))
        model.save(.lineItem(1))
        model.setText("Other", for: .lineItem(2))
        model.save(.lineItem(2))
        #expect(recorder.edits.count == 1)

        recorder.release()
        await model.waitForSaves()

        #expect(recorder.descriptions == ["First", "Second", "Other"])
        #expect(model.text(for: .lineItem(1)) == "Second")
        // Saving item 2 must not revert item 1 to the fetched description.
        #expect(recorder.lastLineItems.first(where: { $0.id == 1 })?.description == "Second")
        #expect(!model.isModified(.lineItem(1)))
        #expect(!model.isModified(.lineItem(2)))
    }

    @Test func invalidNumbersAreNotSent() {
        let recorder = EditRecorder()
        let model = InvoiceDetailModel(invoice: invoice()) { try await recorder.send($0) }

        model.setText("abc", for: .quantity(1))
        model.save(.lineItem(1))

        #expect(model.error == Strings.Detail.invalidNumber)
        #expect(recorder.edits.isEmpty)
    }

    @Test func quantityEditsUpdateTheLiveTotal() {
        let model = InvoiceDetailModel(invoice: invoice()) { _ in }

        model.setText("2", for: .quantity(1))

        #expect(model.lineAmount(for: model.invoice.lineItems![0]) == 100)
        #expect(model.liveAmount == 150)
        #expect(model.isModified(.lineItem(1)))
    }

    @Test func disappearingSavesPendingEditsAndReportsFailuresAppWide() async {
        let recorder = EditRecorder()
        recorder.fails = true
        let model = InvoiceDetailModel(invoice: invoice()) { try await recorder.send($0) }
        let received = MessageBox()
        let observer = NotificationCenter.default.addObserver(forName: .detailSaveFailed, object: nil, queue: nil) { note in
            let message = note.userInfo?["message"] as? String
            MainActor.assumeIsolated { received.message = message }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        model.setText("Unsaved notes", for: .notes)
        model.viewDidDisappear()
        await model.waitForSaves()

        #expect(recorder.edits.count == 1)
        #expect(received.message == Strings.InvoiceDetail.failedActionGeneric(Strings.Detail.Action.saveNotes))
        #expect(model.error == nil)
    }
}

@MainActor
private final class EditRecorder {
    var edits: [InvoiceEdit] = []
    var holdsNextSend = false
    var fails = false
    private var gate: CheckedContinuation<Void, Never>?

    func send(_ edit: InvoiceEdit) async throws {
        edits.append(edit)
        if holdsNextSend {
            holdsNextSend = false
            await withCheckedContinuation { gate = $0 }
        }
        if fails { throw URLError(.notConnectedToInternet) }
    }

    func release() {
        gate?.resume()
        gate = nil
    }

    var subjects: [String] {
        edits.compactMap { edit -> String? in
            guard case .subject(let subject) = edit else { return nil }
            return subject
        }
    }

    var descriptions: [String] {
        edits.compactMap { edit -> String? in
            guard case .lineItem(_, let description, _, _, _) = edit else { return nil }
            return description
        }
    }

    var lastLineItems: [LineItem] {
        for edit in edits.reversed() {
            if case .lineItem(_, _, _, _, let allLineItems) = edit { return allLineItems }
        }
        return []
    }
}

@MainActor
private final class MessageBox {
    var message: String?
}
