//
//  HarvestExporter.swift
//  Harvie
//

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "Export")

/// Orchestrates a full export of a Harvest account. Walks every supported
/// API resource via `HarvestRawAPIClient`, writes one `<resource>.json` and
/// one `<resource>.csv` per resource into the target folder, plus a top-level
/// `manifest.json` summarising the run.
///
/// The exporter never reads or writes SwiftData — every record comes fresh
/// from the Harvest API.
actor HarvestExporter {

    // MARK: - Resource catalog

    /// Every resource the exporter knows how to dump. Stable case names are
    /// used as both stable identifiers (for user resource toggles) and to
    /// derive output filenames.
    enum Resource: String, CaseIterable, Identifiable, Sendable {
        case company
        case users
        case roles
        case projects
        case tasks
        case clients
        case contacts
        case timeEntries = "time_entries"
        case expenses
        case expenseCategories = "expense_categories"
        case invoices
        case invoiceItemCategories = "invoice_item_categories"
        case invoicePayments = "invoice_payments"
        case invoiceMessages = "invoice_messages"
        case estimates
        case estimateItemCategories = "estimate_item_categories"
        case estimateMessages = "estimate_messages"
        case projectUserAssignments = "project_user_assignments"
        case projectTaskAssignments = "project_task_assignments"
        case userBillableRates = "user_billable_rates"
        case userCostRates = "user_cost_rates"
        case userProjectAssignments = "user_project_assignments"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .company: return "Company"
            case .users: return "Users"
            case .roles: return "Roles"
            case .projects: return "Projects"
            case .tasks: return "Tasks"
            case .clients: return "Clients"
            case .contacts: return "Contacts"
            case .timeEntries: return "Time Entries"
            case .expenses: return "Expenses"
            case .expenseCategories: return "Expense Categories"
            case .invoices: return "Invoices"
            case .invoiceItemCategories: return "Invoice Item Categories"
            case .invoicePayments: return "Invoice Payments"
            case .invoiceMessages: return "Invoice Messages"
            case .estimates: return "Estimates"
            case .estimateItemCategories: return "Estimate Item Categories"
            case .estimateMessages: return "Estimate Messages"
            case .projectUserAssignments: return "Project User Assignments"
            case .projectTaskAssignments: return "Project Task Assignments"
            case .userBillableRates: return "User Billable Rates"
            case .userCostRates: return "User Cost Rates"
            case .userProjectAssignments: return "User Project Assignments"
            }
        }

        /// Filename stem (no extension).
        var fileStem: String { rawValue }
    }

    // MARK: - Progress + result types

    struct Progress: Sendable {
        let resource: Resource
        let resourceDisplayName: String
        let completedResources: Int
        let totalResources: Int
    }

    struct ResourceResult: Sendable {
        let resource: Resource
        let recordCount: Int
        let errorMessage: String?
    }

    struct Summary: Sendable {
        let folderURL: URL
        let startedAt: Date
        let finishedAt: Date
        let results: [ResourceResult]

        var totalRecords: Int { results.reduce(0) { $0 + $1.recordCount } }
        var successfulResources: Int { results.filter { $0.errorMessage == nil }.count }
        var hasFailures: Bool { results.contains { $0.errorMessage != nil } }
    }

    // MARK: - Dependencies

    private let client: HarvestRawAPIClient

    init(client: HarvestRawAPIClient = .shared) {
        self.client = client
    }

    // MARK: - Public API

    /// Runs the export. Calls `progress` from the actor context — the caller
    /// is responsible for hopping back to its own isolation domain (typically
    /// `@MainActor`) inside the closure.
    func runExport(
        to folderURL: URL,
        selectedResources: Set<Resource>,
        credentials: HarvestCredentials,
        progress: @Sendable (Progress) -> Void
    ) async throws -> Summary {
        let startedAt = Date()
        // Canonical case order so output is deterministic and child resources
        // always come after their parent.
        let resources = Resource.allCases.filter { selectedResources.contains($0) }

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        var state = ExportState()
        var results: [ResourceResult] = []

        for (index, resource) in resources.enumerated() {
            progress(Progress(
                resource: resource,
                resourceDisplayName: resource.displayName,
                completedResources: index,
                totalResources: resources.count
            ))

            do {
                let count = try await export(
                    resource,
                    state: &state,
                    credentials: credentials,
                    into: folderURL
                )
                results.append(ResourceResult(resource: resource, recordCount: count, errorMessage: nil))
            } catch {
                if case HarvestRawAPIClient.RawAPIError.unauthorized = error {
                    throw error
                }
                logger.error("Resource \(resource.rawValue) failed: \(error.localizedDescription)")
                results.append(ResourceResult(
                    resource: resource,
                    recordCount: 0,
                    errorMessage: error.localizedDescription
                ))
            }
        }

        let summary = Summary(
            folderURL: folderURL,
            startedAt: startedAt,
            finishedAt: Date(),
            results: results
        )

        try writeManifest(summary, into: folderURL)
        return summary
    }

    /// Mutable bag of parent-id arrays collected during the export so that
    /// per-parent sub-resources have something to iterate over.
    private struct ExportState {
        var invoiceIDs: [Int] = []
        var estimateIDs: [Int] = []
        var projectIDs: [Int] = []
        var userIDs: [Int] = []
    }

    private func export(
        _ resource: Resource,
        state: inout ExportState,
        credentials: HarvestCredentials,
        into folderURL: URL
    ) async throws -> Int {
        switch resource {
        case .company:
            return try await exportSingleton(resource, credentials: credentials, into: folderURL)

        case .users:
            let rows = try await exportList(resource, path: "users", credentials: credentials, into: folderURL)
            state.userIDs = ids(in: rows)
            return rows.count

        case .projects:
            let rows = try await exportList(resource, path: "projects", credentials: credentials, into: folderURL)
            state.projectIDs = ids(in: rows)
            return rows.count

        case .invoices:
            let rows = try await exportList(resource, path: "invoices", credentials: credentials, into: folderURL)
            state.invoiceIDs = ids(in: rows)
            return rows.count

        case .estimates:
            let rows = try await exportList(resource, path: "estimates", credentials: credentials, into: folderURL)
            state.estimateIDs = ids(in: rows)
            return rows.count

        case .roles, .tasks, .clients, .contacts, .timeEntries,
             .expenses, .expenseCategories,
             .invoiceItemCategories, .estimateItemCategories:
            return try await exportList(resource, path: resource.rawValue, credentials: credentials, into: folderURL).count

        case .invoicePayments:
            return try await exportPerParent(resource, parentIDs: state.invoiceIDs,
                pathBuilder: { "invoices/\($0)/payments" }, parentKey: "invoice_id",
                credentials: credentials, into: folderURL)
        case .invoiceMessages:
            return try await exportPerParent(resource, parentIDs: state.invoiceIDs,
                pathBuilder: { "invoices/\($0)/messages" }, parentKey: "invoice_id",
                credentials: credentials, into: folderURL)
        case .estimateMessages:
            return try await exportPerParent(resource, parentIDs: state.estimateIDs,
                pathBuilder: { "estimates/\($0)/messages" }, parentKey: "estimate_id",
                credentials: credentials, into: folderURL)
        case .projectUserAssignments:
            return try await exportPerParent(resource, parentIDs: state.projectIDs,
                pathBuilder: { "projects/\($0)/user_assignments" }, parentKey: "project_id",
                credentials: credentials, into: folderURL)
        case .projectTaskAssignments:
            return try await exportPerParent(resource, parentIDs: state.projectIDs,
                pathBuilder: { "projects/\($0)/task_assignments" }, parentKey: "project_id",
                credentials: credentials, into: folderURL)
        case .userBillableRates:
            return try await exportPerParent(resource, parentIDs: state.userIDs,
                pathBuilder: { "users/\($0)/billable_rates" }, parentKey: "user_id",
                credentials: credentials, into: folderURL)
        case .userCostRates:
            return try await exportPerParent(resource, parentIDs: state.userIDs,
                pathBuilder: { "users/\($0)/cost_rates" }, parentKey: "user_id",
                credentials: credentials, into: folderURL)
        case .userProjectAssignments:
            return try await exportPerParent(resource, parentIDs: state.userIDs,
                pathBuilder: { "users/\($0)/project_assignments" }, parentKey: "user_id",
                credentials: credentials, into: folderURL)
        }
    }

    private func ids(in rows: [[String: Any]]) -> [Int] {
        rows.compactMap { ($0["id"] as? NSNumber)?.intValue }
    }

    // MARK: - Per-resource workers

    private func exportSingleton(
        _ resource: Resource,
        credentials: HarvestCredentials,
        into folderURL: URL
    ) async throws -> Int {
        let data = try await client.fetchObject(path: resource.rawValue, credentials: credentials)
        try writeJSON(data, name: resource.fileStem, into: folderURL)

        // Wrap singleton object in a one-row array for the CSV.
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let csv = CSVWriter.makeCSV(rows: [object])
            try csv.write(to: folderURL.appendingPathComponent("\(resource.fileStem).csv"))
        }
        return 1
    }

    /// Fetches a paginated list endpoint, writes JSON + CSV, and returns the
    /// parsed rows so the caller can extract IDs for downstream per-parent
    /// resources.
    @discardableResult
    private func exportList(
        _ resource: Resource,
        path: String,
        credentials: HarvestCredentials,
        into folderURL: URL,
        extraQuery: [URLQueryItem] = []
    ) async throws -> [[String: Any]] {
        let data = try await client.fetchAllPages(
            path: path,
            resourceKey: resource.rawValue,
            credentials: credentials,
            extraQuery: extraQuery
        )
        try writeJSON(data, name: resource.fileStem, into: folderURL)

        let rows = (try JSONSerialization.jsonObject(with: data) as? [Any] ?? [])
            .compactMap { $0 as? [String: Any] }
        let csv = CSVWriter.makeCSV(rows: rows)
        try csv.write(to: folderURL.appendingPathComponent("\(resource.fileStem).csv"))
        return rows
    }

    private func exportPerParent(
        _ resource: Resource,
        parentIDs: [Int],
        pathBuilder: (Int) -> String,
        parentKey: String,
        credentials: HarvestCredentials,
        into folderURL: URL
    ) async throws -> Int {
        var merged: [[String: Any]] = []

        for parentID in parentIDs {
            let path = pathBuilder(parentID)
            do {
                let data = try await client.fetchAllPages(
                    path: path,
                    resourceKey: resource.rawValue,
                    credentials: credentials
                )
                let rows = (try JSONSerialization.jsonObject(with: data) as? [Any] ?? [])
                    .compactMap { $0 as? [String: Any] }
                for var row in rows {
                    if row[parentKey] == nil {
                        row[parentKey] = parentID
                    }
                    merged.append(row)
                }
            } catch HarvestRawAPIClient.RawAPIError.notFound {
                // Some sub-resources 404 for parents that have none — skip silently.
                continue
            } catch HarvestRawAPIClient.RawAPIError.missingResourceKey {
                // Some Harvest endpoints (e.g. user rates for inactive users)
                // return shapes we don't recognise — skip rather than abort.
                continue
            }
        }

        let jsonData = try JSONSerialization.data(
            withJSONObject: merged,
            options: [.prettyPrinted, .sortedKeys]
        )
        try writeJSON(jsonData, name: resource.fileStem, into: folderURL)
        let csv = CSVWriter.makeCSV(rows: merged)
        try csv.write(to: folderURL.appendingPathComponent("\(resource.fileStem).csv"))
        return merged.count
    }

    // MARK: - Writing helpers

    private func writeJSON(_ data: Data, name: String, into folderURL: URL) throws {
        let url = folderURL.appendingPathComponent("\(name).json")
        try data.write(to: url)
    }

    private func writeManifest(_ summary: Summary, into folderURL: URL) throws {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        let resources = summary.results.map { result -> [String: Any] in
            var dict: [String: Any] = [
                "resource": result.resource.rawValue,
                "display_name": result.resource.displayName,
                "record_count": result.recordCount,
                "json_file": "\(result.resource.fileStem).json",
                "csv_file": "\(result.resource.fileStem).csv"
            ]
            if let error = result.errorMessage {
                dict["error"] = error
            }
            return dict
        }

        let manifest: [String: Any] = [
            "app": "Harvie",
            "app_version": appVersion,
            "app_build": buildNumber,
            "started_at": isoFormatter.string(from: summary.startedAt),
            "finished_at": isoFormatter.string(from: summary.finishedAt),
            "total_records": summary.totalRecords,
            "resources": resources
        ]

        let data = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: folderURL.appendingPathComponent("manifest.json"))
    }
}
