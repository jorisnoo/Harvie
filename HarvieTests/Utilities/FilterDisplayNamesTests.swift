//
//  FilterDisplayNamesTests.swift
//  HarvieTests
//

import Foundation
import Testing
@testable import Harvie

@Suite("Filter display names")
@MainActor
struct FilterDisplayNamesTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    @Test func persistedRawValuesAreUnchanged() {
        #expect(InvoiceSortOption.allCases.map(\.rawValue) == ["Issue Date", "Due Date", "Paid Date"])
        #expect(DateFilterPeriod.allCases.map(\.rawValue) == ["Month", "Quarter", "Half Year", "Year"])
    }

    @Test func everyOptionHasADisplayName() {
        #expect(InvoiceSortOption.allCases.allSatisfy { !$0.displayName.isEmpty })
        #expect(DateFilterPeriod.allCases.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test func quarterAndHalfYearLabels() {
        #expect(DateFilterPeriod.quarter.displayLabel(for: date(2026, 4), calendar: calendar) == "Q2 2026")
        #expect(DateFilterPeriod.quarter.displayLabel(for: date(2025, 12), calendar: calendar) == "Q4 2025")
        #expect(DateFilterPeriod.halfYear.displayLabel(for: date(2026, 6), calendar: calendar) == "H1 2026")
        #expect(DateFilterPeriod.halfYear.displayLabel(for: date(2026, 7), calendar: calendar) == "H2 2026")
    }
}
