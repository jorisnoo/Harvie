//
//  SaveStatusIndicator.swift
//  Harvie
//

import SwiftUI

/// A checkmark shown briefly after an inline edit saves, with a spinner while saving.
struct SaveStatusIndicator: View {
    let isSaving: Bool
    let showsSaved: Bool

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .opacity(showsSaved ? 1 : 0)
            .accessibilityLabel(Strings.Detail.saved)
            .accessibilityHidden(!showsSaved)
            .overlay {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.6)
                        .accessibilityLabel(Strings.Detail.saving)
                }
            }
    }
}
