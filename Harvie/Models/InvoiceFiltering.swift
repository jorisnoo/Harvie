//
//  InvoiceFiltering.swift
//  Harvie
//

import Foundation

enum InvoiceSortOption: String, CaseIterable {
    case issueDate = "Issue Date"
    case dueDate = "Due Date"
    case paidDate = "Paid Date"
}

enum SortDirection {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

enum DateFilterPeriod: String, CaseIterable {
    case month = "Month"
    case quarter = "Quarter"
    case halfYear = "Half Year"
    case year = "Year"

    var defaultPeriodCount: Int {
        switch self {
        case .month: 12
        case .quarter: 8
        case .halfYear: 4
        case .year: 5
        }
    }

    func periods(count: Int? = nil) -> [Date] {
        let n = count ?? defaultPeriodCount
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .month:
            return (0..<n).compactMap { monthsAgo in
                calendar.date(byAdding: .month, value: -monthsAgo, to: now)
                    .flatMap { calendar.date(from: calendar.dateComponents([.year, .month], from: $0)) }
            }
        case .quarter:
            return (0..<n).compactMap { quartersAgo in
                calendar.date(byAdding: .month, value: -quartersAgo * 3, to: now)
                    .flatMap { date in
                        let month = calendar.component(.month, from: date)
                        let year = calendar.component(.year, from: date)
                        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
                        return calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1))
                    }
            }
        case .halfYear:
            return (0..<n).compactMap { halvesAgo in
                calendar.date(byAdding: .month, value: -halvesAgo * 6, to: now)
                    .flatMap { date in
                        let month = calendar.component(.month, from: date)
                        let year = calendar.component(.year, from: date)
                        let halfStartMonth = month <= 6 ? 1 : 7
                        return calendar.date(from: DateComponents(year: year, month: halfStartMonth, day: 1))
                    }
            }
        case .year:
            return (0..<n).compactMap { yearsAgo in
                calendar.date(byAdding: .year, value: -yearsAgo, to: now)
                    .flatMap { calendar.date(from: calendar.dateComponents([.year], from: $0)) }
            }
        }
    }

    func contains(_ date: Date, in period: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .month:
            return calendar.isDate(date, equalTo: period, toGranularity: .month)
        case .quarter:
            let dateQuarter = (calendar.component(.month, from: date) - 1) / 3
            let periodQuarter = (calendar.component(.month, from: period) - 1) / 3
            return dateQuarter == periodQuarter &&
                calendar.component(.year, from: date) == calendar.component(.year, from: period)
        case .halfYear:
            let dateHalf = calendar.component(.month, from: date) <= 6 ? 1 : 2
            let periodHalf = calendar.component(.month, from: period) <= 6 ? 1 : 2
            return dateHalf == periodHalf &&
                calendar.component(.year, from: date) == calendar.component(.year, from: period)
        case .year:
            return calendar.isDate(date, equalTo: period, toGranularity: .year)
        }
    }

    func format(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        switch self {
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        case .quarter:
            let quarter = (calendar.component(.month, from: date) - 1) / 3 + 1
            return "Q\(quarter) \(year)"
        case .halfYear:
            let half = calendar.component(.month, from: date) <= 6 ? 1 : 2
            return "H\(half) \(year)"
        case .year:
            return "\(year)"
        }
    }
}
