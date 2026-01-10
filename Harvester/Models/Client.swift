//
//  Client.swift
//  Harvester
//

import Foundation

struct ClientReference: Codable, Identifiable {
    let id: Int
    let name: String
}

struct Client: Codable, Identifiable {
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

struct ClientsResponse: Codable {
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
