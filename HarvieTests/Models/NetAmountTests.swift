//
//  NetAmountTests.swift
//  HarvieTests
//

import Foundation
import Testing
@testable import Harvie

@MainActor
@Suite("Net Amounts")
struct NetAmountTests {

    @Test("Open invoice subtracts both taxes")
    func openInvoice() {
        let invoice = TestDocuments.invoice(amount: 108.1, dueAmount: 108.1, tax2Amount: 8.1)
        #expect(invoice.netDisplayAmount == 100)
    }

    @Test("Partially paid invoice prorates the tax")
    func partiallyPaidInvoice() {
        let invoice = TestDocuments.invoice(amount: 120, dueAmount: 60, tax2Amount: 20)
        #expect(invoice.netDisplayAmount == 50)
    }

    @Test("Paid invoice uses the full net amount")
    func paidInvoice() {
        let invoice = TestDocuments.invoice(amount: 120, dueAmount: 0, state: .paid, tax2Amount: 20)
        #expect(invoice.netDisplayAmount == 100)
    }

    @Test("Untaxed invoice is unchanged")
    func untaxedInvoice() {
        #expect(TestDocuments.invoice(amount: 100, dueAmount: 100).netDisplayAmount == 100)
    }
}
