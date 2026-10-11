//
//  TemplateResolver.swift
//  Harvie
//

import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "TemplateResolver")

/// Looks up the template and per-client settings used to render a document's PDF.
@MainActor
struct TemplateResolver {
    let context: ModelContext

    func clientOverride(for clientId: Int) -> ClientOverride? {
        first(FetchDescriptor<ClientOverride>(predicate: #Predicate { $0.clientId == clientId }))
    }

    /// `settings` with the client's overrides applied.
    func settings(_ settings: AppSettings, forClient clientId: Int) -> AppSettings {
        settings.resolved(with: clientOverride(for: clientId))
    }

    func template(id: UUID) -> InvoiceTemplate? {
        first(FetchDescriptor<InvoiceTemplate>(predicate: #Predicate { $0.id == id }))
    }

    /// The selected template, falling back to the first template by name when none is
    /// selected or the selected one no longer exists (e.g. after it was deleted or re-seeded).
    func template(for settings: AppSettings) -> InvoiceTemplate? {
        if let id = settings.selectedTemplateId, let selected = template(id: id) {
            return selected
        }
        return first(FetchDescriptor<InvoiceTemplate>(sortBy: [SortDescriptor(\.name)]))
    }

    private func first<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> T? {
        var descriptor = descriptor
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("Failed to fetch \(String(describing: T.self)): \(error.localizedDescription)")
            return nil
        }
    }
}
