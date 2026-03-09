//
//  Mod97CalculatorTests.swift
//  HarvieTests
//

import Testing
@testable import Harvie

@Suite("Mod97 Calculator")
struct Mod97CalculatorTests {

    @Test("Calculates mod 97 correctly for simple values")
    func calculateSimple() {
        #expect(Mod97Calculator.calculate("97") == 0)
        #expect(Mod97Calculator.calculate("98") == 1)
        #expect(Mod97Calculator.calculate("194") == 0)
    }

    @Test("Calculates mod 97 for large numbers")
    func calculateLarge() {
        #expect(Mod97Calculator.calculate("123456789012345678") == 123456789012345678 % 97)
    }

    @Test("Returns 0 for empty string")
    func emptyString() {
        #expect(Mod97Calculator.calculate("") == 0)
    }

    @Test("Converts letter A to 10")
    func convertA() {
        #expect(Mod97Calculator.convertToNumeric("A") == "10")
    }

    @Test("Converts letter Z to 35")
    func convertZ() {
        #expect(Mod97Calculator.convertToNumeric("Z") == "35")
    }

    @Test("Converts AB to 1011")
    func convertAB() {
        #expect(Mod97Calculator.convertToNumeric("AB") == "1011")
    }

    @Test("Converts CH to 1217 (for Swiss country code)")
    func convertCH() {
        #expect(Mod97Calculator.convertToNumeric("CH") == "1217")
    }

    @Test("Numbers remain unchanged")
    func numbersUnchanged() {
        #expect(Mod97Calculator.convertToNumeric("12345") == "12345")
    }

    @Test("Mixed letters and numbers converted correctly")
    func mixedConversion() {
        // A=10, 1=1, B=11, 2=2 → "101112"
        #expect(Mod97Calculator.convertToNumeric("A1B2") == "101112")
    }

    @Test("Parameterized letter conversion", arguments: [
        ("A", "10"),
        ("B", "11"),
        ("C", "12"),
        ("D", "13"),
        ("E", "14"),
        ("F", "15"),
        ("G", "16"),
        ("H", "17"),
        ("I", "18"),
        ("J", "19"),
        ("K", "20"),
        ("L", "21"),
        ("M", "22"),
        ("N", "23"),
        ("O", "24"),
        ("P", "25"),
        ("Q", "26"),
        ("R", "27"),
        ("S", "28"),
        ("T", "29"),
        ("U", "30"),
        ("V", "31"),
        ("W", "32"),
        ("X", "33"),
        ("Y", "34"),
        ("Z", "35")
    ])
    func letterConversion(letter: String, expected: String) {
        #expect(Mod97Calculator.convertToNumeric(letter) == expected)
    }
}
