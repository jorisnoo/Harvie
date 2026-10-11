//
//  CSVWriterTests.swift
//  HarvieTests
//

import Foundation
import Testing
@testable import Harvie

@Suite("CSV Writer")
struct CSVWriterTests {

    private func makeRows(_ json: String) throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [[String: Any]])
    }

    @Test("JSON integers 0 and 1 stay numeric; booleans stay booleans")
    func integersNotCoercedToBooleans() throws {
        let rows = try makeRows(
            #"[{"id": 7, "quantity": 1, "weekly_capacity": 0, "active": true, "archived": false}]"#
        )
        let csv = try #require(String(data: CSVWriter.makeCSV(rows: rows), encoding: .utf8))

        // Columns: id pinned first, rest alphabetical
        #expect(csv.contains("id,active,archived,quantity,weekly_capacity"))
        #expect(csv.contains("7,true,false,1,0"))
    }

    @Test("Fields containing separators and quotes are escaped")
    func escapesSpecialCharacters() throws {
        let rows = try makeRows(#"[{"id": 1, "name": "Acme, \"Inc\""}]"#)
        let csv = try #require(String(data: CSVWriter.makeCSV(rows: rows), encoding: .utf8))

        #expect(csv.contains(#""Acme, ""Inc""""#))
    }

    @Test("Text that spreadsheets would run as a formula is neutralised", arguments: [
        "=HYPERLINK(\"https://example.com\")", "+41 44 000 00 00", "-1+2", "@SUM(A1)", "\tdata", "\rdata"
    ])
    func neutralisesFormulas(text: String) throws {
        let csv = try #require(String(data: CSVWriter.makeCSV(rows: [["id": 1, "notes": text]]), encoding: .utf8))
        let cell = try #require(csv.components(separatedBy: "\r\n").dropFirst().first?.dropFirst(2))
        #expect(cell.hasPrefix("'") || cell.hasPrefix("\"'"))
    }

    @Test("Numbers keep their sign; ordinary text is unchanged")
    func numbersAndPlainTextUntouched() throws {
        let rows = try makeRows(#"[{"id": 3, "amount": -12.5, "balance": 0, "notes": "Paid - thanks"}]"#)
        let csv = try #require(String(data: CSVWriter.makeCSV(rows: rows), encoding: .utf8))

        #expect(csv.contains("id,amount,balance,notes"))
        #expect(csv.contains("3,-12.5,0,Paid - thanks"))
    }

    @Test("Formula-like column names are neutralised too")
    func neutralisesHeaders() throws {
        let csv = try #require(String(data: CSVWriter.makeCSV(rows: [["=cmd": "x"]]), encoding: .utf8))
        #expect(csv == "'=cmd\r\nx\r\n")
    }
}
