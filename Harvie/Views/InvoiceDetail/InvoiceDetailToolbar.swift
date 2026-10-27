//
//  InvoiceDetailToolbar.swift
//  Harvie
//

import SwiftUI

/// Preview, export and state actions for the invoice detail view.
struct InvoiceDetailToolbar: ToolbarContent {
    enum Action {
        case preview, export, changeDate, sendViaEmail, markAsPaid, markAsDraft, markAsOpen, delete
        /// A draft's send action, which first checks the issue date.
        case send(InvoiceDetailView.SendAction)
    }

    let state: InvoiceState
    let canExport: Bool
    let isPreviewing: Bool
    let isProcessing: Bool
    let isSendingEmail: Bool
    let isPerformingSheetAction: Bool
    let canDelete: Bool
    let perform: (Action) -> Void

    private var canSendEmail: Bool {
        !isProcessing && !isPreviewing && !isSendingEmail && canExport
    }

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                perform(.preview)
            } label: {
                if isPreviewing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Label(Strings.InvoiceDetail.previewButton, systemImage: "eye")
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(isPreviewing || isProcessing || !canExport)
            .help(canExport ? Strings.InvoiceDetail.previewTooltip : Strings.InvoiceDetail.creditorRequiredTooltip)
            .accessibilityLabel(Strings.InvoiceDetail.previewButton)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                perform(.export)
            } label: {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Label(Strings.InvoiceDetail.exportQRBill, systemImage: "square.and.arrow.down")
                }
            }
            .disabled(isProcessing || isPreviewing || !canExport)
            .help(canExport ? Strings.InvoiceDetail.exportTooltip : Strings.InvoiceDetail.creditorRequiredTooltip)
            .accessibilityLabel(Strings.InvoiceDetail.exportQRBill)
        }

        if state == .draft {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    perform(.changeDate)
                } label: {
                    Label(Strings.InvoiceDetail.changeDate, systemImage: "calendar")
                }
                .help(Strings.InvoiceDetail.changeDate)
            }
        }

        if state == .draft {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        perform(.send(.sendViaEmail))
                    } label: {
                        Label(Strings.InvoiceDetail.sendViaEmail, systemImage: "envelope")
                    }
                    .disabled(!canSendEmail)

                    Divider()

                    Button {
                        perform(.send(.markAsSent))
                    } label: {
                        Label(Strings.InvoiceDetail.markAsSent, systemImage: "text.badge.checkmark")
                    }
                } label: {
                    Label(Strings.InvoiceDetail.send, systemImage: "paperplane")
                        .opacity(isSendingEmail ? 0 : 1)
                        .overlay {
                            if isSendingEmail {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                }
                .disabled(isPerformingSheetAction || isSendingEmail)
                .help(Strings.InvoiceDetail.sendTooltip)
                .accessibilityLabel(Strings.InvoiceDetail.send)
            }
        }

        if state == .open {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    perform(.markAsPaid)
                } label: {
                    Label(Strings.InvoiceDetail.markAsPaid, systemImage: "banknote")
                }
                .disabled(isPerformingSheetAction)
                .help(Strings.InvoiceDetail.markAsPaid)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        perform(.sendViaEmail)
                    } label: {
                        Label(Strings.InvoiceDetail.sendViaEmail, systemImage: "envelope")
                    }
                    .disabled(!canSendEmail)

                    Button {
                        perform(.changeDate)
                    } label: {
                        Label(Strings.InvoiceDetail.changeDate, systemImage: "calendar")
                    }

                    Divider()

                    Button {
                        perform(.markAsDraft)
                    } label: {
                        Label(Strings.InvoiceDetail.markAsDraft, systemImage: "arrow.uturn.backward")
                    }
                } label: {
                    Label(Strings.Common.more, systemImage: "ellipsis.circle")
                }
                .disabled(isPerformingSheetAction)
            }
        }

        if state == .paid {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    perform(.markAsOpen)
                } label: {
                    Label(Strings.InvoiceDetail.markAsOpen, systemImage: "arrow.uturn.backward")
                }
                .disabled(isPerformingSheetAction)
                .help(Strings.InvoiceDetail.markAsOpen)
            }
        }

        if canDelete {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    perform(.delete)
                } label: {
                    Label(Strings.DeleteInvoice.title, systemImage: "trash")
                }
                .disabled(isPerformingSheetAction)
                .help(Strings.DeleteInvoice.title)
            }
        }
    }
}
