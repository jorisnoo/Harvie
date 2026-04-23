//
//  DocumentSource.swift
//  Harvie
//

import Foundation

enum DocumentSource: String, CaseIterable, Identifiable {
    case invoices
    case estimates

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .invoices: Strings.DocumentSource.invoices
        case .estimates: Strings.DocumentSource.estimates
        }
    }
}
