//
//  ConfirmationSheet.swift
//  HarvestQRBill
//

import SwiftUI

struct ConfirmationSheet<Content: View>: View {
    let title: String
    let message: String?
    let detail: String?
    let confirmLabel: String
    let isProcessing: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let width: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        message: String? = nil,
        detail: String? = nil,
        confirmLabel: String,
        isProcessing: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        width: CGFloat = 280,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.message = message
        self.detail = detail
        self.confirmLabel = confirmLabel
        self.isProcessing = isProcessing
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.width = width
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)

            if let message {
                Text(message)
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content

            HStack {
                Button(Strings.Common.cancel, role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button(confirmLabel) {
                    onConfirm()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
        .padding()
        .frame(width: width)
    }
}

extension ConfirmationSheet where Content == EmptyView {
    init(
        title: String,
        message: String? = nil,
        detail: String? = nil,
        confirmLabel: String,
        isProcessing: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        width: CGFloat = 280
    ) {
        self.init(
            title: title,
            message: message,
            detail: detail,
            confirmLabel: confirmLabel,
            isProcessing: isProcessing,
            onConfirm: onConfirm,
            onCancel: onCancel,
            width: width
        ) {
            EmptyView()
        }
    }
}
