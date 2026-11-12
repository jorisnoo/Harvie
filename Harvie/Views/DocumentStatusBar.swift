//
//  DocumentStatusBar.swift
//  Harvie
//

import SwiftUI

/// One document's contribution to the status bar totals.
struct DocumentTotal {
    let currency: String
    let gross: Decimal
    let net: Decimal
}

/// The bar under a document list: the count, and one total per currency that
/// switches between including and excluding VAT when clicked.
struct DocumentStatusBar: View {
    let count: String
    let totals: [DocumentTotal]

    @AppStorage("statusBarExcludesVAT") private var excludesVAT = false

    private var formattedTotal: String {
        Dictionary(grouping: totals, by: \.currency)
            .sorted { $0.key < $1.key }
            .map { currency, totals in
                let sum = totals.reduce(Decimal.zero) { $0 + (excludesVAT ? $1.net : $1.gross) }
                return CurrencyFormatter.format(sum, currency: currency)
            }
            .joined(separator: " \u{00B7} ")
    }

    var body: some View {
        if !totals.isEmpty {
            HStack {
                Text(count)
                    .contentTransition(.numericText())
                Spacer()
                Button {
                    excludesVAT.toggle()
                } label: {
                    Text("\(formattedTotal) \(excludesVAT ? Strings.StatusBar.excludingVAT : Strings.StatusBar.includingVAT)")
                        .contentTransition(.numericText())
                }
                .buttonStyle(.plain)
                .help(excludesVAT ? Strings.StatusBar.showIncludingVAT : Strings.StatusBar.showExcludingVAT)
            }
            .lineLimit(1)
            .animation(.default, value: formattedTotal)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
}
