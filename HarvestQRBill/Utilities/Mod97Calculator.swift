//
//  Mod97Calculator.swift
//  HarvestQRBill
//

import Foundation

struct Mod97Calculator {
    static func calculate(_ numericString: String) -> Int {
        var remainder = 0

        for char in numericString {
            guard let digit = Int(String(char)) else { continue }
            remainder = (remainder * 10 + digit) % 97
        }

        return remainder
    }

    static func convertToNumeric(_ string: String) -> String {
        var numericString = ""

        for char in string {
            if char.isNumber {
                numericString.append(char)
            } else if char.isLetter {
                let value = Int(char.asciiValue!) - Int(Character("A").asciiValue!) + 10
                numericString.append(String(value))
            }
        }

        return numericString
    }
}
