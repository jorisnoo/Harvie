//
//  TemplateVariablesPanel.swift
//  Harvie
//

import SwiftUI

struct TemplateVariablesPanel: View {
    var onInsert: (String) -> Void

    private var categories: [(String, [TemplateVariable])] {
        typealias Vars = Strings.TemplateVariables
        return [
            (Vars.invoice, [
                TemplateVariable(token: "invoice.number", label: Vars.number),
                TemplateVariable(token: "invoice.amount", label: Vars.totalAmount),
                TemplateVariable(token: "invoice.currency", label: Vars.currency),
                TemplateVariable(token: "invoice.subject", label: Vars.subject),
                TemplateVariable(token: "invoice.notes", label: Vars.notes),
                TemplateVariable(token: "invoice.issueDate", label: Vars.issueDate),
                TemplateVariable(token: "invoice.dueDate", label: Vars.dueDate),
                TemplateVariable(token: "invoice.subtotal", label: Vars.subtotal),
                TemplateVariable(token: "invoice.tax", label: Vars.taxPercent),
                TemplateVariable(token: "invoice.taxAmount", label: Vars.taxAmount),
                TemplateVariable(token: "invoice.discount", label: Vars.discountPercent),
                TemplateVariable(token: "invoice.discountAmount", label: Vars.discountAmount),
                TemplateVariable(token: "invoice.totalHours", label: Vars.totalHours)
            ]),
            (Vars.client, [
                TemplateVariable(token: "client.name", label: Vars.name),
                TemplateVariable(token: "client.address", label: Vars.address)
            ]),
            (Vars.creditor, [
                TemplateVariable(token: "creditor.name", label: Vars.name),
                TemplateVariable(token: "creditor.iban", label: Vars.iban),
                TemplateVariable(token: "creditor.street", label: Vars.street),
                TemplateVariable(token: "creditor.buildingNumber", label: Vars.buildingNumber),
                TemplateVariable(token: "creditor.postalCode", label: Vars.postalCode),
                TemplateVariable(token: "creditor.town", label: Vars.town),
                TemplateVariable(token: "creditor.country", label: Vars.country)
            ]),
            (Vars.lineItems, [
                TemplateVariable(token: "#lineItems", label: Vars.loopStart),
                TemplateVariable(token: "/lineItems", label: Vars.loopEnd),
                TemplateVariable(token: "description", label: Vars.description),
                TemplateVariable(token: "quantity", label: Vars.quantity),
                TemplateVariable(token: "unitPrice", label: Vars.unitPrice),
                TemplateVariable(token: "amount", label: Vars.amount)
            ]),
            (Vars.conditionals, [
                TemplateVariable(token: "#if invoice.hasNotes", label: Vars.ifHasNotes),
                TemplateVariable(token: "/if", label: Vars.endIf),
                TemplateVariable(token: "#if invoice.hasTax", label: Vars.ifHasTax),
                TemplateVariable(token: "#if invoice.hasDiscount", label: Vars.ifHasDiscount),
                TemplateVariable(token: "#if invoice.hasSubject", label: Vars.ifHasSubject)
            ]),
            (Vars.labels, [
                TemplateVariable(token: "labels.invoice", label: Vars.invoice),
                TemplateVariable(token: "labels.description", label: Vars.description),
                TemplateVariable(token: "labels.quantity", label: Vars.quantity),
                TemplateVariable(token: "labels.unitPrice", label: Vars.unitPrice),
                TemplateVariable(token: "labels.rate", label: Vars.rate),
                TemplateVariable(token: "labels.price", label: Vars.price),
                TemplateVariable(token: "labels.amount", label: Vars.amount),
                TemplateVariable(token: "labels.subtotal", label: Vars.subtotal),
                TemplateVariable(token: "labels.vat", label: Vars.vat),
                TemplateVariable(token: "labels.discount", label: Vars.discount),
                TemplateVariable(token: "labels.total", label: Vars.total),
                TemplateVariable(token: "labels.totalDue", label: Vars.totalDue),
                TemplateVariable(token: "labels.totalHours", label: Vars.totalHours),
                TemplateVariable(token: "labels.due", label: Vars.due),
                TemplateVariable(token: "labels.date", label: Vars.date),
                TemplateVariable(token: "labels.currency", label: Vars.currency),
                TemplateVariable(token: "labels.from", label: Vars.from),
                TemplateVariable(token: "labels.billTo", label: Vars.billTo),
                TemplateVariable(token: "labels.details", label: Vars.details),
                TemplateVariable(token: "labels.iban", label: Vars.iban),
                TemplateVariable(token: "labels.paymentDetails", label: Vars.paymentDetails),
                TemplateVariable(token: "labels.notes", label: Vars.notes),
                TemplateVariable(token: "labels.re", label: Vars.reSubject)
            ]),
            (Vars.filters, [
                TemplateVariable(token: "invoice.issueDate | date:\"dd.MM.yyyy\"", label: Vars.dateFormat),
                TemplateVariable(token: "invoice.amount | currency", label: Vars.currencyFormat),
                TemplateVariable(token: "quantity | numberTrimmed:1", label: Vars.trimmedNumberFormat)
            ])
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(categories, id: \.0) { category, variables in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 4) {
                            ForEach(variables) { variable in
                                Button {
                                    onInsert(variable.token)
                                } label: {
                                    Text(variable.label)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .help("{{\(variable.token)}}")
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}

private struct TemplateVariable: Identifiable {
    let token: String
    let label: String

    var id: String { token }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
