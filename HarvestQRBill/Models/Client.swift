//
//  Client.swift
//  HarvestQRBill
//

import Foundation

struct ClientReference: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}

struct ClientContact: Codable, Identifiable, Sendable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct ClientContactsResponse: Codable, Sendable {
    let contacts: [ClientContact]

    enum CodingKeys: String, CodingKey {
        case contacts
    }
}

struct Client: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let isActive: Bool
    let address: String?
    let currency: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, address, currency
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ClientsResponse: Codable, Sendable {
    let clients: [Client]
    let perPage: Int
    let totalPages: Int
    let totalEntries: Int
    let nextPage: Int?
    let previousPage: Int?
    let page: Int

    enum CodingKeys: String, CodingKey {
        case clients
        case perPage = "per_page"
        case totalPages = "total_pages"
        case totalEntries = "total_entries"
        case nextPage = "next_page"
        case previousPage = "previous_page"
        case page
    }
}
