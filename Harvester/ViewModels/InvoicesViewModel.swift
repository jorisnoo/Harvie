//
//  InvoicesViewModel.swift
//  Harvester
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class InvoicesViewModel {
    var invoices: [Invoice] = []
    var selectedInvoice: Invoice?
    var isLoading = false
    var error: String?
    var stateFilter: InvoiceState? = .open
    var hasValidCredentials = false

    private let apiService = HarvestAPIService.shared
    private let keychainService = KeychainService.shared

    var filteredInvoices: [Invoice] {
        invoices
    }

    func loadInvoices() async {
        isLoading = true
        error = nil

        do {
            let credentials = try await keychainService.loadHarvestCredentials()

            guard credentials.isValid else {
                hasValidCredentials = false
                error = "Please configure your Harvest API credentials in Settings."
                isLoading = false
                return
            }

            hasValidCredentials = true

            let fetchedInvoices = try await apiService.fetchAllInvoices(
                credentials: credentials,
                state: stateFilter
            )

            invoices = fetchedInvoices
        } catch KeychainService.KeychainError.notFound {
            hasValidCredentials = false
            error = "Please configure your Harvest API credentials in Settings."
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadInvoices()
    }

    func getCredentials() async throws -> HarvestCredentials {
        try await keychainService.loadHarvestCredentials()
    }

    func getCreditorInfo() async throws -> CreditorInfo {
        try await keychainService.loadCreditorInfo()
    }
}
