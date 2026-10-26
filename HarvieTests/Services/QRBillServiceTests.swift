import Foundation
import PDFKit
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

    // MARK: - Payload

    @Test func generatesExactPayload() {
        let data = QRBillData(
            creditorIBAN: "CH93 0076 2011 6238 5295 7",
            creditorAddress: StructuredAddress(name: "Fixture AG", streetName: "Main Street", buildingNumber: "1",
                                               postalCode: "8000", town: "Zürich", country: "CH"),
            amount: Decimal(string: "1234.5"),
            currency: "CHF",
            debtorAddress: nil,
            reference: "RF18539007547034",
            unstructuredMessage: "Invoice INV-7",
            billingInfo: nil
        )
        let empty: [String] = Array(repeating: "", count: 7)
        var fields: [String] = ["SPC", "0200", "1", "CH9300762011623852957",
                                "S", "Fixture AG", "Main Street", "1", "8000", "Zürich", "CH"]
        fields += empty // ultimate creditor
        fields += ["1234.50", "CHF"]
        fields += empty // no debtor
        fields += ["SCOR", "RF18539007547034", "Invoice INV-7", "EPD"]
        let expected = fields.joined(separator: "\r\n")

        let payload = data.generatePayload()
        #expect(payload == expected)
        #expect(payload.components(separatedBy: "\r\n").count == 31)
        #expect(!payload.hasSuffix("\r\n"))
    }

    @Test func createdDataProducesThirtyOneFieldPayload() throws {
        let data = try QRBillService().createQRBillData(invoice: TestDocuments.invoice(), creditorInfo: TestDocuments.creditor)
        let fields = data.generatePayload().components(separatedBy: "\r\n")
        #expect(fields.count == 31)
        #expect(fields[3] == "CH9300762011623852957")
        #expect(fields[18] == "100.00")
        #expect(fields[27] == "SCOR")
        #expect(fields[29] == "Invoice INV-7")
    }

    @Test func qrCodeImageHasNoQuietZone() throws {
        // The renderer draws the image at 46 mm, which must be the code itself.
        let service = QRBillService()
        let data = try service.createQRBillData(invoice: TestDocuments.invoice(), creditorInfo: TestDocuments.creditor)
        let image = try #require(service.generateQRCodeImage(from: data))

        var pixel: UInt8 = 255
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        // Draw so that only the top-left image pixel, a finder pattern corner, lands in the context.
        context.draw(image, in: CGRect(x: 0, y: 1 - CGFloat(image.height), width: CGFloat(image.width), height: CGFloat(image.height)))
        #expect(pixel < 128)
    }

    @Test func slipShowsTheAcceptancePoint() throws {
        let service = QRBillService()
        let data = try service.createQRBillData(invoice: TestDocuments.invoice(), creditorInfo: TestDocuments.creditor)
        let image = try #require(service.generateQRCodeImage(from: data))
        let page = try #require(QRBillRenderer(labels: TemplateLanguage.de.qrBillLabels).renderQRBillPage(data: data, qrImage: image))
        #expect(page.string?.contains("Annahmestelle") == true)
    }

    @Test(arguments: [("1234.5", "1234.50"), ("0.005", "0.01"), ("1000000", "1000000.00"), ("999999999.99", "999999999.99")])
    func formatsAmountsInFixedFormat(input: String, expected: String) throws {
        let amount = try #require(Decimal(string: input))
        #expect(QRBillData.formatAmount(amount) == expected)
    }

    @Test func amountFormattingIgnoresTheUserLocale() {
        // A user locale such as ar_SA would otherwise turn the amount into Arabic-Indic digits.
        #expect(QRBillData.amountFormatter.locale.identifier == "en_US_POSIX")
        #expect(QRBillData.amountFormatter.usesGroupingSeparator == false)
    }

    // MARK: - Character set

    @Test func keepsPermittedCharacters() {
        let text = "Café Zürich, Genève; Łódź Ș ș Ț ț € ½"
        #expect(QRBillText.sanitize(text) == text)
    }

    @Test func transliteratesOrDropsUnsupportedCharacters() {
        #expect(QRBillText.sanitize("Acme 🚀 GmbH") == "Acme GmbH")
        #expect(QRBillText.sanitize("№ 5") == "No 5")
        #expect(QRBillText.sanitize("Москва") == "Moskva")
        #expect(QRBillText.sanitize("O’Brien – Ltd") == "O'Brien - Ltd")
        #expect(QRBillText.sanitize("e\u{301}") == "é")

        let chinese = QRBillText.sanitize("北京公司")
        #expect(!chinese.isEmpty)
        #expect(chinese.unicodeScalars.allSatisfy(QRBillText.isPermitted))
    }

    @Test func payloadFieldsAreSanitizedBeforeTheyAreCut() {
        #expect(QRBillText.payloadField("Line\none", limit: 70) == "Line one")
        // "№" becomes two characters, so the limit must apply afterwards.
        #expect(QRBillText.payloadField("№№", limit: 3) == "NoN")
    }

    @Test func slipTextMatchesThePayload() throws {
        let debtor = StructuredAddress(name: "Börse 🚀 AG", streetName: "Straße №", buildingNumber: "5",
                                       postalCode: "8000", town: "Zürich", country: "CH")
        let data = try QRBillService().createQRBillData(
            invoice: TestDocuments.invoice(), creditorInfo: TestDocuments.creditor, debtorAddress: debtor
        )
        let debtorFields = Array(data.generatePayload().components(separatedBy: "\r\n")[20...26])
        #expect(debtorFields == ["S", "Börse AG", "Straße No", "5", "8000", "Zürich", "CH"])
        #expect(data.debtorAddress?.name == "Börse AG")
        #expect(data.debtorAddress?.streetName == "Straße No")
    }

    @Test func emptyDebtorAfterSanitizingIsOmitted() throws {
        let debtor = StructuredAddress(name: "🚀", streetName: nil, buildingNumber: nil,
                                       postalCode: "8000", town: "Zürich", country: "CH")
        let data = try QRBillService().createQRBillData(
            invoice: TestDocuments.invoice(), creditorInfo: TestDocuments.creditor, debtorAddress: debtor
        )
        #expect(data.debtorAddress == nil)
    }
}
