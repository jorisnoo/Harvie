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
    private let modelContext: ModelContext

    deinit {
        renderTask?.cancel()
    }

    init(template: InvoiceTemplate, modelContext: ModelContext) {
        self.template = template
        self.htmlContent = template.htmlContent
        self.cssContent = template.cssContent
        self.name = template.name
        self.columnVisibility = template.columnVisibility
        self.modelContext = modelContext
        updatePreview()
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
        template.htmlContent = htmlContent
        template.cssContent = cssContent
        template.columnVisibility = columnVisibility
        template.updatedAt = Date()
        try? modelContext.save()
        isDirty = false
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
