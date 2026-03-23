//
//  PaymentTerm.swift
//  Harvie
//

import Foundation

enum PaymentTerm: Hashable {
    case uponReceipt
    case net15
    case net30
    case net45
    case net60
    case custom(days: Int)

    var days: Int {
        switch self {
        case .uponReceipt: 0
        case .net15: 15
        case .net30: 30
        case .net45: 45
        case .net60: 60
        case .custom(let days): days
        }
    }

    var label: String {
        switch self {
        case .uponReceipt: Strings.InvoiceDetail.uponReceipt
        case .net15: "Net 15"
        case .net30: "Net 30"
        case .net45: "Net 45"
        case .net60: "Net 60"
        case .custom(let days): Strings.InvoiceDetail.customDays(days)
        }
    }

    static func from(issueDate: Date, dueDate: Date) -> PaymentTerm {
        let days = Calendar.current.dateComponents([.day], from: issueDate, to: dueDate).day ?? 0
        switch days {
        case 0: return .uponReceipt
        case 15: return .net15
        case 30: return .net30
        case 45: return .net45
        case 60: return .net60
        default: return .custom(days: max(days, 0))
        }
    }

    func dueDate(from issueDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: issueDate) ?? issueDate
    }

    static let standardCases: [PaymentTerm] = [.uponReceipt, .net15, .net30, .net45, .net60]

    static func pickerCases(including current: PaymentTerm) -> [PaymentTerm] {
        if case .custom = current {
            return standardCases + [current]
        }
        return standardCases
    }
}
