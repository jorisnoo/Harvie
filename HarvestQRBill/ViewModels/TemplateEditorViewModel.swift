//
//  TemplateEditorViewModel.swift
//  HarvestQRBill
//

import Combine
import Foundation
import PDFKit
import SwiftData
import SwiftUI

@Observable
@MainActor
final class TemplateEditorViewModel {
    var template: InvoiceTemplate
    var htmlContent: String
    var cssContent: String
    var name: String
    var columnVisibility: ColumnVisibility
    var isDirty = false
    var isRendering = false
    var previewHTML: String = ""
    var selectedTab: EditorTab = .html
    var error: String?

    enum EditorTab: String, CaseIterable {
        case html = "HTML"
        case css = "CSS"
    }

    @ObservationIgnored nonisolated(unsafe) private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var fileWatcher: TemplateFileWatcher?
    private let modelContext: ModelContext

    deinit {
        renderTask?.cancel()
        fileWatcher?.stop()
    }

    init(template: InvoiceTemplate, modelContext: ModelContext) {
        self.template = template
        self.htmlContent = template.resolvedHTMLContent()
        self.cssContent = template.resolvedCSSContent()
        self.name = template.name
        self.columnVisibility = template.columnVisibility
        self.modelContext = modelContext
        updatePreview()
        startFileWatcher()
    }

    var isBuiltIn: Bool {
        template.isBuiltIn
    }

    func contentChanged() {
        isDirty = true
        schedulePreviewUpdate()
    }

    func save() {
        template.name = name
        template.columnVisibility = columnVisibility
        template.updatedAt = Date()

        if !template.isBuiltIn {
            TemplateFileManager.save(html: htmlContent, css: cssContent, for: template.id, name: name)
            // Clear SwiftData content — disk is source of truth
            template.htmlContent = ""
            template.cssContent = ""
        }

        try? modelContext.save()
        isDirty = false

        // Restart watcher since files may have been recreated
        startFileWatcher()
    }

    func openInExternalEditor() {
        guard !template.isBuiltIn else { return }
        // Ensure files exist on disk before opening
        if !TemplateFileManager.filesExist(for: template.id) {
            TemplateFileManager.save(html: htmlContent, css: cssContent, for: template.id, name: name)
        }
        TemplateFileManager.openInEditor(for: template.id)
    }

    func revealInFinder() {
        guard !template.isBuiltIn else { return }
        if !TemplateFileManager.filesExist(for: template.id) {
            TemplateFileManager.save(html: htmlContent, css: cssContent, for: template.id, name: name)
        }
        TemplateFileManager.revealInFinder(for: template.id)
    }

    func columnVisibilityChanged() {
        template.columnVisibility = columnVisibility
        try? modelContext.save()
        updatePreview()
    }

    func insertVariable(_ variable: String) {
        let token = "{{\(variable)}}"

        switch selectedTab {
        case .html:
            htmlContent += token
        case .css:
            cssContent += token
        }

        contentChanged()
    }

    private func startFileWatcher() {
        fileWatcher?.stop()
        guard !template.isBuiltIn else { return }

        let dir = TemplateFileManager.existingDirectory(for: template.id)
            ?? TemplateFileManager.templateDirectory(for: template.id, name: name)
        fileWatcher = TemplateFileWatcher { [weak self] in
            self?.reloadFromDisk()
        }
        fileWatcher?.watch(directory: dir)
    }

    private func reloadFromDisk() {
        guard !template.isBuiltIn else { return }
        if let html = TemplateFileManager.loadHTML(for: template.id) {
            htmlContent = html
        }
        if let css = TemplateFileManager.loadCSS(for: template.id) {
            cssContent = css
        }
        isDirty = false
        updatePreview()
    }

    private func schedulePreviewUpdate() {
        renderTask?.cancel()
        renderTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            updatePreview()
        }
    }

    func updatePreview() {
        var context = TemplateContext.sampleDictionary()
        if let userLogo = LogoStorage.dataURI() {
            var creditor = context["creditor"] as! [String: Any]
            creditor["logo"] = userLogo
            creditor["hasLogo"] = true
            context["creditor"] = creditor
        }
        let processedHTML = TemplateEngine.render(htmlContent, with: context)
        let css = cssContent + "\n" + columnVisibility.cssVariables()
        previewHTML = buildPreviewDocument(html: processedHTML, css: css)
    }

    private func buildPreviewDocument(html: String, css: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            width: 210mm;
            min-height: 297mm;
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
        }
        \(css)
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }
}
