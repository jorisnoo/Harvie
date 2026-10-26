//
//  ExportViewModel.swift
//  Harvie
//

import AppKit
import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "ExportVM")

@Observable
@MainActor
final class ExportViewModel {
    var outputFolder: URL?
    var selectedResources: Set<HarvestExporter.Resource> = Set(HarvestExporter.Resource.allCases)

    var isExporting = false
    var progress: Double = 0
    var progressMessage: String = ""
    var error: String?
    var lastSummary: HarvestExporter.Summary?
    var credentialsAvailable = true

    private let exporter = HarvestExporter()
    private let keychain = KeychainService.shared
    /// Set until the running export has actually finished, even after it was cancelled.
    private var exportTask: Task<Void, Never>?
    /// Bumped on every start and cancel so late progress updates and results from an
    /// earlier run are ignored.
    @ObservationIgnored private var exportGeneration = 0

    var canStartExport: Bool {
        !isExporting
            && exportTask == nil
            && outputFolder != nil
            && !selectedResources.isEmpty
            && credentialsAvailable
    }

    func checkCredentials() async {
        do {
            _ = try await keychain.loadHarvestCredentials()
            credentialsAvailable = true
        } catch {
            credentialsAvailable = false
        }
    }

    // MARK: - Resource selection

    func toggle(_ resource: HarvestExporter.Resource) {
        if selectedResources.contains(resource) {
            selectedResources.remove(resource)
        } else {
            selectedResources.insert(resource)
        }
    }

    func selectAll() {
        selectedResources = Set(HarvestExporter.Resource.allCases)
    }

    func selectNone() {
        selectedResources = []
    }

    func isSelected(_ resource: HarvestExporter.Resource) -> Bool {
        selectedResources.contains(resource)
    }

    // MARK: - Folder picking

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = Strings.DataExport.selectFolderPrompt
        panel.prompt = Strings.Export.choosePrompt

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputFolder = url
    }

    func revealLastExport() {
        guard let folder = lastSummary?.folderURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    // MARK: - Export lifecycle

    func startExport() {
        guard canStartExport, let folder = outputFolder else { return }

        error = nil
        lastSummary = nil
        progress = 0
        progressMessage = ""
        isExporting = true
        exportGeneration += 1

        let generation = exportGeneration
        let resourcesToExport = selectedResources
        let exporter = self.exporter

        exportTask = Task { [weak self] in
            let result: Result<HarvestExporter.Summary, Error>
            do {
                let credentials = try await KeychainService.shared.loadHarvestCredentials()
                let summary = try await exporter.runExport(
                    to: folder,
                    selectedResources: resourcesToExport,
                    credentials: credentials,
                    progress: { progressUpdate in
                        Task { @MainActor in
                            self?.applyProgress(progressUpdate, generation: generation)
                        }
                    }
                )
                result = .success(summary)
            } catch {
                result = .failure(error)
            }
            self?.finishExport(with: result, generation: generation)
        }
    }

    func cancelExport() {
        guard isExporting else { return }
        exportTask?.cancel()
        exportGeneration += 1
        isExporting = false
        progressMessage = ""
    }

    private func finishExport(with result: Result<HarvestExporter.Summary, Error>, generation: Int) {
        exportTask = nil
        // A cancelled export finishes "normally" (the exporter records per-resource
        // cancellations) — don't report it as a success.
        guard generation == exportGeneration else { return }
        isExporting = false

        switch result {
        case .success(let summary):
            lastSummary = summary
            progress = 1
            progressMessage = Strings.DataExport.successSummary(
                summary.successfulResources,
                summary.totalRecords
            )
        case .failure(let error):
            self.error = error.localizedDescription
        }
    }

    private func applyProgress(_ update: HarvestExporter.Progress, generation: Int) {
        guard generation == exportGeneration, isExporting else { return }
        progress = update.totalResources == 0
            ? 0
            : Double(update.completedResources) / Double(update.totalResources)
        progressMessage = Strings.DataExport.progressMessage(
            update.resourceDisplayName,
            update.completedResources,
            update.totalResources
        )
    }
}
