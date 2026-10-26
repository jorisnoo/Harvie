//
//  InvoiceAmountsSection.swift
//  Harvie
//

import SwiftUI

/// The amount due or paid, key dates, tax and discount, updated live while line items are edited.
struct InvoiceAmountsSection: View {
    let invoice: Invoice
    let model: InvoiceDetailModel
    let onChangeDate: () -> Void

    private var isDraft: Bool { invoice.state == .draft }

    private var formattedAmount: String {
        CurrencyFormatter.format(model.liveAmount, currency: invoice.currency)
    }

    private var formattedDueAmount: String {
        CurrencyFormatter.format(model.liveDueAmount, currency: invoice.currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(invoice.state == .paid ? formattedAmount : formattedDueAmount)
                .font(.title)
                .fontWeight(.bold)
                .contentTransition(.numericText())
                .animation(.default, value: model.liveAmount)

            if invoice.state != .paid, model.liveDueAmount != model.liveAmount {
                Text(Strings.InvoiceDetail.ofTotal(formattedAmount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            if let sentAt = invoice.sentAt,
               Calendar.current.isDate(sentAt, inSameDayAs: invoice.issueDate) {
                Text(Strings.InvoiceDetail.issuedAndSent(
                    invoice.issueDate.formatted(date: .long, time: .omitted),
                    sentAt.formatted(date: .omitted, time: .shortened)
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                changeDateLink(Strings.InvoiceDetail.issued(invoice.issueDate.formatted(date: .long, time: .omitted)))

                if let sentAt = invoice.sentAt {
                    Text(Strings.InvoiceDetail.sent(sentAt.formatted(date: .long, time: .shortened)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            changeDateLink(Strings.InvoiceDetail.due(invoice.dueDate.formatted(date: .long, time: .omitted)))

            if let paidAt = invoice.paidAt {
                Text(Strings.InvoiceDetail.paid(paidAt.formatted(date: .long, time: .shortened)))
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            if let tax = invoice.tax, invoice.taxAmount != nil {
                Text(Strings.InvoiceDetail.inclTax(tax.formatted(), CurrencyFormatter.format(model.liveTaxAmount, currency: invoice.currency)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
                    .animation(.default, value: model.liveAmount)
            }

            if let discount = invoice.discount, invoice.discountAmount != nil {
                Text(Strings.InvoiceDetail.discount(discount.formatted(), CurrencyFormatter.format(model.liveDiscountAmount, currency: invoice.currency)))
                    .font(.caption)
                    .contentTransition(.numericText())
                    .animation(.default, value: model.liveAmount)
            }
        }
    }

    /// A date line that opens the change-date sheet while the invoice is a draft.
    private func changeDateLink(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .underline(isDraft, color: .secondary.opacity(0.5))
            .onTapGesture { if isDraft { onChangeDate() } }
            .linkPointerStyle(isEnabled: isDraft)
            .accessibilityAddTraits(isDraft ? .isButton : [])
    }
}
