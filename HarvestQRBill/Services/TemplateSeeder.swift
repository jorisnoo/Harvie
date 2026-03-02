//
//  TemplateSeeder.swift
//  HarvestQRBill
//

import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "TemplateSeeder")

struct TemplateSeeder {
    struct BuiltInTemplate {
        let name: String
        let htmlFile: String
        let cssFile: String
    }

    static let builtInTemplates = [
        BuiltInTemplate(name: "Modern", htmlFile: "modern", cssFile: "modern"),
        BuiltInTemplate(name: "Classic", htmlFile: "classic", cssFile: "classic"),
        BuiltInTemplate(name: "Minimal", htmlFile: "minimal", cssFile: "minimal")
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<InvoiceTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let existingTemplates = (try? context.fetch(descriptor)) ?? []

        if existingTemplates.isEmpty {
            for builtIn in builtInTemplates {
                let html = loadResource(named: builtIn.htmlFile, extension: "html") ?? ""
                let css = loadResource(named: builtIn.cssFile, extension: "css") ?? ""

                let template = InvoiceTemplate(
                    name: builtIn.name,
                    htmlContent: html,
                    cssContent: css,
                    isBuiltIn: true
                )
                context.insert(template)
            }

            #if DEBUG
            logger.debug("Seeded \(builtInTemplates.count) built-in templates")
            #endif
        } else {
            refreshBuiltInTemplates(existingTemplates, context: context)
        }

        migrateUserTemplatesToDisk(context: context)
        synchronizeDiskTemplates(context: context)
        try? context.save()
    }

    /// One-time migration: for user templates with content in SwiftData but no files on disk,
    /// write content to disk and clear the SwiftData fields.
    @MainActor
    private static func migrateUserTemplatesToDisk(context: ModelContext) {
        let descriptor = FetchDescriptor<InvoiceTemplate>(
            predicate: #Predicate { $0.isBuiltIn == false }
        )
        guard let userTemplates = try? context.fetch(descriptor) else { return }

        for template in userTemplates {
            let hasContent = !template.htmlContent.isEmpty || !template.cssContent.isEmpty
            let hasFiles = TemplateFileManager.filesExist(for: template.id)

            if hasContent && !hasFiles {
                TemplateFileManager.save(
                    html: template.htmlContent,
                    css: template.cssContent,
                    for: template.id,
                    name: template.name
                )
                template.htmlContent = ""
                template.cssContent = ""

                #if DEBUG
                logger.debug("Migrated user template '\(template.name)' to disk")
                #endif
            }
        }
    }

    /// Discovers template folders on disk and creates/removes SwiftData entries to match.
    @MainActor
    private static func synchronizeDiskTemplates(context: ModelContext) {
        let discovered = TemplateFileManager.discoverTemplates()

        let descriptor = FetchDescriptor<InvoiceTemplate>(
            predicate: #Predicate { $0.isBuiltIn == false }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingIDs = Set(existing.map(\.id))

        // Create entries for newly discovered templates
        for entry in discovered where !existingIDs.contains(entry.id) {
            let template = InvoiceTemplate(
                id: entry.id,
                name: entry.name,
                htmlContent: "",
                cssContent: "",
                isBuiltIn: false
            )
            context.insert(template)

            #if DEBUG
            logger.debug("Auto-discovered template '\(entry.name)' from disk")
            #endif
        }

        // Remove orphaned SwiftData entries whose folders no longer exist on disk
        let discoveredIDs = Set(discovered.map(\.id))
        for template in existing where !discoveredIDs.contains(template.id) {
            context.delete(template)

            #if DEBUG
            logger.debug("Removed orphaned template '\(template.name)' (folder deleted from disk)")
            #endif
        }
    }

    private static func refreshBuiltInTemplates(_ templates: [InvoiceTemplate], context: ModelContext) {
        let existingNames = Set(templates.map(\.name))
        let validNames = Set(builtInTemplates.map(\.name))

        // Remove stale built-in entries no longer in the canonical list
        for template in templates where !validNames.contains(template.name) {
            context.delete(template)

            #if DEBUG
            logger.debug("Removed stale built-in template: \(template.name)")
            #endif
        }

        for template in templates {
            guard let builtIn = builtInTemplates.first(where: { $0.name == template.name }) else {
                continue
            }

            if let html = loadResource(named: builtIn.htmlFile, extension: "html") {
                template.htmlContent = html
            }

            if let css = loadResource(named: builtIn.cssFile, extension: "css") {
                template.cssContent = css
            }

            template.updatedAt = Date()
        }

        // Insert any new built-in templates not yet in the database
        for builtIn in builtInTemplates where !existingNames.contains(builtIn.name) {
            let html = loadResource(named: builtIn.htmlFile, extension: "html") ?? ""
            let css = loadResource(named: builtIn.cssFile, extension: "css") ?? ""

            let template = InvoiceTemplate(
                name: builtIn.name,
                htmlContent: html,
                cssContent: css,
                isBuiltIn: true
            )
            context.insert(template)

            #if DEBUG
            logger.debug("Seeded new built-in template: \(builtIn.name)")
            #endif
        }

        #if DEBUG
        logger.debug("Refreshed \(templates.count) built-in templates from bundle")
        #endif
    }

    private static func loadResource(named name: String, extension ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Templates") else {
            // Try without subdirectory (flat bundle)
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                #if DEBUG
                logger.warning("Template resource not found: \(name).\(ext)")
                #endif
                return nil
            }
            return try? String(contentsOf: url, encoding: .utf8)
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
