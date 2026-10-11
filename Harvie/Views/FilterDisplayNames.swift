//
//  FilterDisplayNames.swift
//  Harvie
//

import Foundation

// Raw values are persisted in settings, so on-screen names come from Strings instead.

extension InvoiceSortOption {
    var displayName: String {
        switch self {
        case .issueDate: Strings.InvoicesList.sortIssueDate
        case .dueDate: Strings.InvoicesList.sortDueDate
        case .paidDate: Strings.InvoicesList.sortPaidDate
        }
    }
}

extension DateFilterPeriod {
    var displayName: String {
        switch self {
        case .month: Strings.InvoicesList.periodMonth
        case .quarter: Strings.InvoicesList.periodQuarter
        case .halfYear: Strings.InvoicesList.periodHalfYear
        case .year: Strings.InvoicesList.periodYear
        }
    }

    /// Localized label for a period start date, e.g. "Q2 2026".
    func displayLabel(for period: Date, calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: period)
        let year = calendar.component(.year, from: period)

        switch self {
        case .quarter: return Strings.InvoicesList.quarterPeriod((month - 1) / 3 + 1, year)
        case .halfYear: return Strings.InvoicesList.halfYearPeriod(month <= 6 ? 1 : 2, year)
        case .month: return period.formatted(.dateTime.month(.wide).year())
        case .year: return String(year)
        }
    }
}
