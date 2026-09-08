import Foundation
@testable import Harvie

@MainActor
enum TestDocuments {
    static func invoice(id: Int = 7, number: String = "INV-7", amount: Decimal = 100, dueAmount: Decimal = 100,
                        state: InvoiceState = .open, tax2Amount: Decimal? = nil) -> Invoice {
        let date = Date(timeIntervalSince1970: 1_788_220_800)
        return Invoice(id: id, clientKey: "fixture", number: number, amount: amount, dueAmount: dueAmount,
                       tax2: tax2Amount == nil ? nil : 5, tax2Amount: tax2Amount,
                       currency: "CHF", state: state, issueDate: date, dueDate: date,
                       createdAt: date, updatedAt: date, client: ClientReference(id: 1, name: "Fixture"))
    }

    static func estimate(id: Int = 7) -> Estimate {
        let date = Date(timeIntervalSince1970: 1_788_220_800)
        return Estimate(id: id, clientKey: "fixture", number: "EST-\(id)", amount: 100,
                        currency: "CHF", state: .draft, issueDate: date, createdAt: date,
                        updatedAt: date, client: ClientReference(id: 1, name: "Fixture"))
    }

    static var creditor: CreditorInfo {
        CreditorInfo(iban: "CH93 0076 2011 6238 5295 7", name: "Fixture", streetName: "Main Street",
                     buildingNumber: "1", postalCode: "8000", town: "Zürich", country: "CH")
    }
}
