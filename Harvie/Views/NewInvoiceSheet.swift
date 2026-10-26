//
//  NewInvoiceSheet.swift
//  Harvie
//

import SwiftUI

struct NewInvoiceSheet: View {
    var viewModel: InvoicesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var loadState = LoadState.loading
    @State private var clients: [Client] = []
    @State private var kinds: [String] = []
    @State private var draft = InvoiceDraft(kind: "Service")
    @State private var isCreating = false
    @State private var error: String?

    private enum LoadState {
        case loading, loaded, failed(String)
    }

    private var currency: String? {
        clients.first { $0.id == draft.clientId }?.currency
    }

    var body: some View {
        VStack(spacing: 0) {
            switch loadState {
            case .loading:
                ProgressView(Strings.NewInvoice.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label(Strings.NewInvoice.loadFailed, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button(Strings.Common.retry) { Task { await loadOptions() } }
                }
            case .loaded:
                form
            }

            Divider()
            footer
        }
        .frame(width: 640, height: 620)
        .interactiveDismissDisabled(isCreating)
        .task { await loadOptions() }
        .alert(Strings.Common.error, isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(Strings.Common.ok) { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker(Strings.NewInvoice.client, selection: $draft.clientId) {
                    Text(Strings.NewInvoice.selectClient).tag(Int?.none)
                    ForEach(clients) { client in
                        Text(client.name).tag(Int?.some(client.id))
                    }
                }

                TextField(Strings.NewInvoice.subject, text: $draft.subject, prompt: Text(Strings.NewInvoice.subjectPlaceholder))

                DatePicker(Strings.InvoiceDetail.issueDate, selection: $draft.issueDate, displayedComponents: .date)

                Picker(Strings.NewInvoice.paymentTerms, selection: $draft.paymentTerm) {
                    ForEach(PaymentTerm.standardCases, id: \.self) { term in
                        Text(term.label).tag(term)
                    }
                }

                LabeledContent(Strings.InvoiceDetail.dueDate) {
                    Text(draft.paymentTerm.dueDate(from: draft.issueDate).formatted(date: .long, time: .omitted))
                }
            }

            Section(Strings.NewInvoice.lineItems) {
                ForEach($draft.lines) { $line in
                    DraftLineItemRow(
                        line: $line,
                        kinds: kinds,
                        formattedAmount: line.amount.map(format) ?? "\u{2014}",
                        canRemove: draft.lines.count > 1
                    ) {
                        draft.lines.removeAll { $0.id == line.id }
                    }
                }

                Button(Strings.NewInvoice.addLineItem, systemImage: "plus") {
                    draft.lines.append(InvoiceDraft.Line(kind: draft.lines.last?.kind ?? kinds.first ?? "Service"))
                }
                .buttonStyle(.borderless)
            }

            Section {
                TextField(Strings.NewInvoice.taxRate, text: $draft.taxRate, prompt: Text(Strings.NewInvoice.taxPlaceholder))

                LabeledContent(Strings.NewInvoice.subtotal) {
                    Text(format(draft.subtotal))
                        .monospacedDigit()
                }

                TextField(Strings.InvoiceDetail.notes, text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack {
            Text(Strings.NewInvoice.draftHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if isCreating {
                ProgressView()
                    .controlSize(.small)
            }

            Button(Strings.Common.cancel, role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button(Strings.NewInvoice.create) { Task { await create() } }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isCreating || draft.newInvoice == nil)
        }
        .padding()
    }

    private func format(_ amount: Decimal) -> String {
        currency.map { CurrencyFormatter.format(amount, currency: $0) } ?? amount.formatted()
    }

    private func loadOptions() async {
        loadState = .loading
        do {
            let options = try await viewModel.loadNewInvoiceOptions()
            clients = options.clients
            kinds = options.kinds.isEmpty ? ["Service"] : options.kinds
            draft = InvoiceDraft(kind: kinds.first { $0 == "Service" } ?? kinds[0])
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func create() async {
        guard let newInvoice = draft.newInvoice, !isCreating else { return }
        isCreating = true
        do {
            try await viewModel.createInvoice(newInvoice)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}

private struct DraftLineItemRow: View {
    @Binding var line: InvoiceDraft.Line
    let kinds: [String]
    let formattedAmount: String
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if kinds.count > 1 {
                Picker(Strings.NewInvoice.kind, selection: $line.kind) {
                    ForEach(kinds, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

            TextField(Strings.InvoiceDetail.description, text: $line.description, prompt: Text(Strings.InvoiceDetail.description), axis: .vertical)
                .labelsHidden()
                .lineLimit(1...4)

            numberField(Strings.NewInvoice.quantity, text: $line.quantity, width: 56)

            Text("\u{00D7}")
                .foregroundStyle(.tertiary)

            numberField(Strings.NewInvoice.unitPrice, text: $line.unitPrice, width: 90)

            Text(formattedAmount)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 110, alignment: .trailing)

            Button(Strings.NewInvoice.removeLineItem, systemImage: "minus.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(!canRemove)
                .help(Strings.NewInvoice.removeLineItem)
        }
    }

    private func numberField(_ title: String, text: Binding<String>, width: CGFloat) -> some View {
        let isInvalid = !text.wrappedValue.isEmpty && DecimalInput.parse(text.wrappedValue) == nil
        return TextField(title, text: text, prompt: Text(title))
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(isInvalid ? .red : .primary)
            .frame(width: width)
    }
}
