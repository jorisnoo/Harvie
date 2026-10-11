//
//  Strings+Detail.swift
//  Harvie
//

import Foundation

extension Strings {
    /// Strings used by the invoice and estimate detail views.
    enum Detail {
        static func invoiceTitle(_ number: String) -> String {
            String(localized: "Invoice \(number)")
        }

        static func estimateTitle(_ number: String) -> String {
            String(localized: "Estimate \(number)")
        }

        static let quantity = String(localized: "Qty")
        static let invalidNumber = String(localized: "Enter a valid quantity and price using your region’s number format.")
        static let saving = String(localized: "Saving")
        static let saved = String(localized: "Saved")

        /// Actions named in "Failed to …" error messages.
        enum Action {
            static let saveTitle = String(localized: "save title")
            static let saveNotes = String(localized: "save notes")
            static let saveLineItem = String(localized: "save line item")
            static let saveIssueDate = String(localized: "save issue date")
            static let markAsSent = String(localized: "mark as sent")
            static let markAsDraft = String(localized: "mark as draft")
            static let markAsPaid = String(localized: "mark as paid")
            static let reopenInvoice = String(localized: "reopen invoice")
        }
    }
}
