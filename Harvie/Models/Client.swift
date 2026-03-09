//
//  Client.swift
//  HarvestQRBill
//

import Foundation

struct ClientReference: Codable, Identifiable, Sendable {
    let id: Int
    let name: String

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct ClientContact: Codable, Identifiable, Sendable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String?

    private enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
    }
}

struct ClientContactsResponse: Codable, Sendable {
    let contacts: [ClientContact]

    private enum CodingKeys: String, CodingKey {
        case contacts
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contacts = try container.decode([ClientContact].self, forKey: .contacts)
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

    private enum CodingKeys: String, CodingKey {
        case id, name, address, currency
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
