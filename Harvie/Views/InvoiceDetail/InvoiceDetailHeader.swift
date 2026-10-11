//
//  InvoiceDetailHeader.swift
//  Harvie
//

import SwiftUI

/// The invoice title (editable inline), state and number · client line.
struct InvoiceDetailHeader: View {
    let invoice: Invoice
    let model: InvoiceDetailModel
    let focus: FocusState<InvoiceDetailModel.Field?>.Binding
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(Strings.InvoiceDetail.invoiceTitle, text: model.binding(for: .subject))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.plain)
                    .focused(focus, equals: .subject)
                    .onSubmit { focus.wrappedValue = nil }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isFocused ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                    )
                    .padding(.leading, -6)

                SaveStatusIndicator(isSaving: model.isSaving(.subject), showsSaved: model.showsSaved(.subject))

                Spacer()

                StateIndicator(state: invoice.state)
            }

            DocumentSubtitle(number: invoice.number, clientName: invoice.client.name)
        }
    }
}
