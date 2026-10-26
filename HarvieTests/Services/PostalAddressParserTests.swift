import Foundation
import Testing
@testable import Harvie

@Suite("Debtor address parsing")
@MainActor
struct PostalAddressParserTests {
    private func parse(_ lines: String...) -> StructuredAddress? {
        PostalAddressParser.parse(lines.joined(separator: "\n"), name: "Client")
    }

    @Test func parsesSwissAddress() throws {
        let address = try #require(parse("Bahnhofstrasse 42", "8001 Zürich", "Switzerland"))
        #expect(address.streetName == "Bahnhofstrasse")
        #expect(address.buildingNumber == "42")
        #expect(address.postalCode == "8001")
        #expect(address.town == "Zürich")
        #expect(address.country == "CH")
        #expect(address.isValid)
    }

    @Test func assumesSwitzerlandOnlyForSwissLookingPostcodes() throws {
        #expect(try #require(parse("Bahnhofstrasse 42", "8001 Zürich")).country == "CH")
        #expect(parse("Hauptstrasse 1", "10115 Berlin") == nil)
    }

    @Test func parsesGermanAddress() throws {
        let address = try #require(parse("Unter den Linden 77", "10117 Berlin", "Deutschland"))
        #expect(address.streetName == "Unter den Linden")
        #expect(address.buildingNumber == "77")
        #expect(address.postalCode == "10117")
        #expect(address.town == "Berlin")
        #expect(address.country == "DE")
    }

    @Test func parsesLiechtensteinAddressWithCountryPrefix() throws {
        let address = try #require(parse("Städtle 1", "FL-9490 Vaduz"))
        #expect(address.postalCode == "9490")
        #expect(address.town == "Vaduz")
        #expect(address.country == "LI")
        #expect(try #require(parse("Städtle 1", "9490 Vaduz", "Fürstentum Liechtenstein")).country == "LI")
    }

    @Test func doesNotMistakeAHouseNumberForAPostcode() throws {
        let address = try #require(parse("221B Baker Street", "London NW1 6XE", "United Kingdom"))
        #expect(address.streetName == "Baker Street")
        #expect(address.buildingNumber == "221B")
        #expect(address.postalCode == "NW1 6XE")
        #expect(address.town == "London")
        #expect(address.country == "GB")

        let split = try #require(parse("10 Downing Street", "London", "SW1A 2AA", "UK"))
        #expect(split.town == "London")
        #expect(split.postalCode == "SW1A 2AA")

        #expect(parse("221 Baker Street", "London", "United Kingdom") == nil)
    }

    @Test func parsesUSAddress() throws {
        let address = try #require(parse("1600 Amphitheatre Parkway", "Mountain View, CA 94043", "USA"))
        #expect(address.streetName == "Amphitheatre Parkway")
        #expect(address.buildingNumber == "1600")
        #expect(address.postalCode == "94043")
        #expect(address.town == "Mountain View CA")
        #expect(address.country == "US")
    }

    @Test func keepsExtraLinesAboveTheStreet() throws {
        let address = try #require(parse("c/o Muster Treuhand AG", "Postfach", "Bahnhofplatz 3", "3011 Bern", "Schweiz"))
        #expect(address.streetName == "c/o Muster Treuhand AG\nPostfach\nBahnhofplatz")
        #expect(address.buildingNumber == "3")
        #expect(address.postalCode == "3011")
        #expect(address.town == "Bern")
        #expect(address.country == "CH")
    }

    @Test func rejectsAddressesItCannotReadConfidently() {
        #expect(parse("Somewhere") == nil)
        #expect(parse("Main Street 1", "Springfield", "Atlantis") == nil)
    }

    @Test(arguments: [("Switzerland", "CH"), ("Suisse", "CH"), ("Svizzera", "CH"), ("ch", "CH"),
                      ("Österreich", "AT"), ("Vereinigte Staaten", "US"), ("U.S.A.", "US"), ("Royaume-Uni", "GB")])
    func resolvesCountryNames(name: String, code: String) {
        #expect(PostalAddressParser.countryCode(from: name) == code)
    }
}
