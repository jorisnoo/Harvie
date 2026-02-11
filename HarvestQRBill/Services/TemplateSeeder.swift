//
//  TemplateSeeder.swift
//  HarvestQRBill
//

import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "TemplateSeeder")

struct TemplateSeeder {
    private static let seedVersionKey = "TemplateSeeder.version"
    private static let currentVersion = 2

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
        let savedVersion = UserDefaults.standard.integer(forKey: seedVersionKey)

        if savedVersion >= currentVersion {
            return
        }

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
        } else if savedVersion < 2 {
            upgradeBuiltInTemplates(existingTemplates)
        }

        try? context.save()
        UserDefaults.standard.set(currentVersion, forKey: seedVersionKey)
    }

    private static func upgradeBuiltInTemplates(_ templates: [InvoiceTemplate]) {
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

        #if DEBUG
        logger.debug("Upgraded \(templates.count) built-in templates to v2")
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
