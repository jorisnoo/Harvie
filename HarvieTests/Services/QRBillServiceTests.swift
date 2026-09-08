import Foundation
import Testing
@testable import Harvie

@Suite("QR bill validation")
@MainActor
struct QRBillServiceTests {
    @Test func rejectsForeignAccount() {
        var creditor = TestDocuments.creditor
        creditor.iban = "DE89370400440532013000"
        #expect(throws: QRBillService.ValidationError.invalidIBAN) {
            try QRBillService().createQRBillData(invoice: TestDocuments.invoice(), creditorInfo: creditor)
        }
    }

    @Test(arguments: [Decimal.zero, Decimal(-1), Decimal(1_000_000_000)])
    func rejectsInvalidAmounts(amount: Decimal) {
        #expect(throws: QRBillService.ValidationError.invalidAmount) {
            try QRBillService().createQRBillData(invoice: TestDocuments.invoice(dueAmount: amount), creditorInfo: TestDocuments.creditor)
        }
    }

    @Test func paidInvoicesDoNotGetPaymentSlips() {
        #expect(!QRBillService.shouldIncludeQRBill(for: TestDocuments.invoice(dueAmount: 0, state: .paid)))
        #expect(!QRBillService.shouldIncludeQRBill(for: TestDocuments.invoice(dueAmount: -1)))
        #expect(QRBillService.shouldIncludeQRBill(for: TestDocuments.invoice(dueAmount: 42)))
    }

    @Test func validatesGeneratedReferenceAndMessage() throws {
        let service = QRBillService()
        let data = try service.createQRBillData(invoice: TestDocuments.invoice(number: "---"), creditorInfo: TestDocuments.creditor)
        #expect(CreditorReferenceGenerator.validate(data.reference!))
        #expect(!CreditorReferenceGenerator.validate("RF78Ä123"))
        #expect(throws: QRBillService.ValidationError.messageTooLong) {
            try service.createQRBillData(
                invoice: TestDocuments.invoice(number: String(repeating: "A", count: 141)), creditorInfo: TestDocuments.creditor
            )
        }
        #expect(throws: QRBillService.ValidationError.messageTooLong) {
            try service.createQRBillData(invoice: TestDocuments.invoice(number: "7\r\nEPD"), creditorInfo: TestDocuments.creditor)
        }
    }

    @Test func addressFieldsStayOnSinglePayloadLines() {
        let address = StructuredAddress(name: "Name\r\nDepartment", streetName: "Main\rStreet", buildingNumber: "1\nA",
                                        postalCode: "8000", town: "Zürich", country: "ch")
        #expect(address.isValid)
        #expect(address.toPayloadLines().count == 7)
        #expect(address.toPayloadLines().allSatisfy { $0.rangeOfCharacter(from: .newlines) == nil })
        #expect(address.toPayloadLines().last == "CH")
    }
}
