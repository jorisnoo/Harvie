//
//  InvoiceNotesEditor.swift
//  Harvie
//

import SwiftUI

/// The invoice notes, rendered as Markdown and editable inline.
struct InvoiceNotesEditor: View {
    let model: InvoiceDetailModel
    let focus: FocusState<InvoiceDetailModel.Field?>.Binding
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Strings.InvoiceDetail.notes)
                .font(.headline)

            TextEditor(text: model.binding(for: .notes))
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .focused(focus, equals: .notes)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isFocused ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                )
                .padding(.leading, -4)
                .overlay {
                    if !isFocused {
                        Text(model.notes.harvestMarkdown)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(4)
                            .background(.background)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Spacer()
                SaveStatusIndicator(isSaving: model.isSaving(.notes), showsSaved: model.showsSaved(.notes))
            }
        }
    }
}
