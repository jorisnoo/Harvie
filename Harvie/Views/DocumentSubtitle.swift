//
//  DocumentSubtitle.swift
//  Harvie
//

import SwiftUI

/// The "number · client" line under a document's title.
struct DocumentSubtitle: View {
    let number: String
    let clientName: String

    var body: some View {
        HStack(spacing: 4) {
            Text(number)
            Text("\u{00B7}")
            Text(clientName)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
