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
    private static let currentVersion = 1

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
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        if existingCount >= builtInTemplates.count {
            UserDefaults.standard.set(currentVersion, forKey: seedVersionKey)
            return
        }

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

        try? context.save()
        UserDefaults.standard.set(currentVersion, forKey: seedVersionKey)

        #if DEBUG
        logger.debug("Seeded \(builtInTemplates.count) built-in templates")
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
