//
//  InvoiceLineItemsSection.swift
//  Harvie
//

import SwiftUI

/// The invoice's line items, each editable inline.
struct InvoiceLineItemsSection: View {
    let items: [LineItem]
    let currency: String
    let model: InvoiceDetailModel
    let focus: FocusState<InvoiceDetailModel.Field?>.Binding
    let focusedField: InvoiceDetailModel.Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 12)

            ForEach(items) { item in
                LineItemRow(item: item, currency: currency, model: model, focus: focus, focusedField: focusedField)

                if item.id != items.last?.id {
                    Divider()
                }
            }

            Divider()
                .padding(.vertical, 12)
        }
    }
}

/// One line item: description, quantity × price and the live amount.
/// Its text is bound to the model, which saves it when a field is left.
struct LineItemRow: View {
    let item: LineItem
    let currency: String
    let model: InvoiceDetailModel
    let focus: FocusState<InvoiceDetailModel.Field?>.Binding
    let focusedField: InvoiceDetailModel.Field?

    private var isEditingDescription: Bool { focusedField == .lineItem(item.id) }
    private var isSaving: Bool { model.isSaving(.lineItem(item.id)) }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    descriptionEditor
                }

                HStack(spacing: 2) {
                    numberField(Strings.Detail.quantity, field: .quantity(item.id))

                    Text("×")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    numberField(Strings.InvoiceDetail.price, field: .unitPrice(item.id))
                }
            }

            Spacer()

            SaveStatusIndicator(isSaving: isSaving, showsSaved: model.showsSaved(.lineItem(item.id)))

            Text(CurrencyFormatter.format(model.lineAmount(for: item), currency: currency))
                .font(.body)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.default, value: model.lineAmount(for: item))
        }
        .padding(.vertical, 8)
    }

    private var descriptionEditor: some View {
        TextEditor(text: model.binding(for: .lineItem(item.id)))
            .font(.body)
            .scrollContentBackground(.hidden)
            .focused(focus, equals: .lineItem(item.id))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isEditingDescription ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
            )
            .padding(.leading, -6)
            .overlay {
                if !isEditingDescription {
                    Text(model.text(for: .lineItem(item.id)).harvestMarkdown)
                        .font(.body)
                        .foregroundStyle(isSaving ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .background(.background)
                        .allowsHitTesting(false)
                }
            }
    }

    private func numberField(_ title: String, field: InvoiceDetailModel.Field) -> some View {
        TextField(title, text: model.binding(for: field))
            .font(.caption)
            .foregroundStyle(.tertiary)
            .textFieldStyle(.roundedBorder)
            .focused(focus, equals: field)
            .fixedSize()
            .onSubmit { focus.wrappedValue = nil }
    }
}
