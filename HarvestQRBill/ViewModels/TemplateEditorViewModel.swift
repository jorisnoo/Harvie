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
    var isDirty = false
    var isRendering = false
    var previewHTML: String = ""
    var selectedTab: EditorTab = .html
    var error: String?

    enum EditorTab: String, CaseIterable {
        case html = "HTML"
        case css = "CSS"
    }

    private var renderTask: Task<Void, Never>?
    private let modelContext: ModelContext

    init(template: InvoiceTemplate, modelContext: ModelContext) {
        self.template = template
        self.htmlContent = template.htmlContent
        self.cssContent = template.cssContent
        self.name = template.name
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
        template.updatedAt = Date()
        try? modelContext.save()
        isDirty = false
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
        let context = TemplateContext.sampleDictionary()
        let processedHTML = TemplateEngine.render(htmlContent, with: context)
        previewHTML = buildPreviewDocument(html: processedHTML, css: cssContent)
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
