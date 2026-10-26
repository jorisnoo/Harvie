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

    /// How far the text editor indents its text (the text view's line fragment padding).
    private static let textInset: CGFloat = 5

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
                .overlay {
                    if !isFocused {
                        Text(model.notes.harvestMarkdown)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.leading, Self.textInset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(.background)
                            .allowsHitTesting(false)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isFocused ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
                )
                // Pull the box out so the text, not the box, lines up with the heading.
                .padding(.leading, -(4 + Self.textInset))

            HStack {
                Spacer()
                SaveStatusIndicator(isSaving: model.isSaving(.notes), showsSaved: model.showsSaved(.notes))
            }
        }
    }
}
