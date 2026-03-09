//
//  InvoicesViewModel+Export.swift
//  HarvestQRBill
//

import AppKit
import Foundation
import os.log
import PDFKit
import SwiftData
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "InvoicesVM+Export")

extension InvoicesViewModel {

    func exportSelectedInvoices(withQRBill: Bool) async {
        let invoicesToExport = selectedInvoices
        guard !invoicesToExport.isEmpty else { return }

        // Show folder picker
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = Strings.Export.selectFolderMessage
        panel.prompt = Strings.Common.select

        let response = await MainActor.run {
            panel.runModal()
        }

        guard response == .OK, let folderURL = panel.url else { return }

        isExporting = true
        exportProgress = 0
        exportError = nil
        exportedCount = 0

        do {
            let credentials = try await KeychainService.shared.loadHarvestCredentials()
            let creditorInfo = try await KeychainService.shared.loadCreditorInfo()

            if withQRBill, !creditorInfo.isValid {
                exportError = Strings.Errors.configureCreditor
                isExporting = false
                return
            }

            let total = invoicesToExport.count

            // Load template if using template mode
            var template: InvoiceTemplate?
            if withQRBill && appSettings.effectivePDFSource == .template {
                guard let templateId = appSettings.selectedTemplateId,
                      let loaded = await loadTemplate(id: templateId) else {
                    exportError = Strings.Errors.noTemplateSelected
                    isExporting = false
                    return
                }
                template = loaded
            }

            for (index, invoice) in invoicesToExport.enumerated() {
                exportProgressMessage = Strings.Export.exportingProgress(index + 1, total, invoice.number)
                exportProgress = Double(index) / Double(total)

                let document = try await generatePDF(
                    for: invoice,
                    withQRBill: withQRBill,
                    credentials: credentials,
                    creditorInfo: creditorInfo,
                    template: template,
                    settings: appSettings
                )

                let date: Date = switch sortOption {
                case .issueDate, .dueDate:
                    invoice.issueDate
                case .paidDate:
                    invoice.effectivePaidDate ?? invoice.issueDate
                }

                let fileName = appSettings.generateFilename(
                    invoiceNumber: invoice.number,
                    creditorName: creditorInfo.name,
                    clientName: invoice.client.name,
                    date: date,
                    issueDate: invoice.issueDate,
                    dueDate: invoice.dueDate,
                    paidDate: invoice.effectivePaidDate
                )
                let fileURL = folderURL.appendingPathComponent(fileName)

                try await PDFService.shared.savePDF(document, to: fileURL)
                exportedCount += 1
            }

            exportProgress = 1.0
            exportProgressMessage = Strings.Export.exportComplete
            showExportSuccess = true
            Analytics.batchExportCompleted(count: exportedCount, withQRBill: withQRBill)
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    func loadTemplate(id: UUID) async -> InvoiceTemplate? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<InvoiceTemplate>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            logger.error("Failed to load template: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Drag & Drop
    // TODO: Drag-and-drop export is temporarily disabled (see InvoicesListView)

    func createDragProvider(for invoice: Invoice) -> NSItemProvider {
        let provider = NSItemProvider()

        let date: Date = switch sortOption {
        case .issueDate, .dueDate:
            invoice.issueDate
        case .paidDate:
            invoice.effectivePaidDate ?? invoice.issueDate
        }

        let fileName = appSettings.generateFilename(
            invoiceNumber: invoice.number,
            creditorName: creditorInfo.name,
            clientName: invoice.client.name,
            date: date,
            issueDate: invoice.issueDate,
            dueDate: invoice.dueDate,
            paidDate: invoice.effectivePaidDate
        )

        provider.suggestedName = (fileName as NSString).deletingPathExtension

        let settings = appSettings
        let creditor = creditorInfo

        provider.registerFileRepresentation(for: .pdf, visibility: .all) { completion in
            Task { @MainActor [weak self] in
                guard let self else {
                    completion(nil, false, nil)
                    return
                }

                do {
                    let credentials = try await KeychainService.shared.loadHarvestCredentials()

                    let template: InvoiceTemplate?
                    if creditor.isValid && settings.effectivePDFSource == .template,
                       let templateId = settings.selectedTemplateId {
                        template = await self.loadTemplate(id: templateId)
                        guard template != nil else {
                            throw NSError(domain: "HarvestQRBill", code: 1, userInfo: [
                                NSLocalizedDescriptionKey: Strings.Errors.noTemplateSelected
                            ])
                        }
                    } else {
                        template = nil
                    }

                    let document = try await self.generatePDF(
                        for: invoice,
                        withQRBill: creditor.isValid,
                        credentials: credentials,
                        creditorInfo: creditor,
                        template: template,
                        settings: settings
                    )

                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(fileName)
                    try await PDFService.shared.savePDF(document, to: tempURL)
                    completion(tempURL, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }

            return Progress()
        }

        return provider
    }

    // MARK: - PDF Generation

    func generatePDF(
        for invoice: Invoice,
        withQRBill: Bool,
        credentials: HarvestCredentials,
        creditorInfo: CreditorInfo,
        template: InvoiceTemplate?,
        settings: AppSettings
    ) async throws -> PDFDocument {
        if withQRBill {
            if let template {
                return try await PDFService.shared.createInvoiceFromTemplate(
                    invoice: invoice,
                    template: template,
                    creditorInfo: creditorInfo,
                    credentials: credentials,
                    language: settings.templateLanguage,
                    labelOverrides: settings.labelOverrides,
                    paidMarkStyle: settings.paidMarkStyle,
                    columnVisibility: settings.columnVisibility
                )
            } else {
                return try await PDFService.shared.createInvoiceWithQRBill(
                    invoice: invoice,
                    credentials: credentials,
                    creditorInfo: creditorInfo,
                    language: settings.templateLanguage,
                    labelOverrides: settings.labelOverrides,
                    paidMarkStyle: settings.paidMarkStyle
                )
            }
        } else {
            let pdfURL = try HarvestAPIService.shared.buildPDFURL(for: invoice, subdomain: credentials.subdomain)
            return try await PDFService.shared.downloadPDF(from: pdfURL)
        }
    }
}
