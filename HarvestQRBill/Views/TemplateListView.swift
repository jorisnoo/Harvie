//
//  TemplateListView.swift
//  HarvestQRBill
//

import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InvoiceTemplate.createdAt) private var templates: [InvoiceTemplate]
    @State private var selectedTemplate: InvoiceTemplate?
    @State private var showDeleteConfirmation = false
    @State private var templateToDelete: InvoiceTemplate?
    @State private var editorControllers: [NSWindowController] = []
    @State private var previewControllers: [NSWindowController] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedTemplate) {
                ForEach(templates) { template in
                    TemplateRow(template: template)
                        .tag(template)
                        .contextMenu {
                            templateContextMenu(for: template)
                        }
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 200)

            HStack(spacing: 8) {
                Button {
                    createTemplate()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New template")

                Button {
                    guard let selected = selectedTemplate else { return }
                    duplicateTemplate(selected)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(selectedTemplate == nil)
                .help("Duplicate template")

                Button {
                    guard let selected = selectedTemplate else { return }

                    if selected.isBuiltIn {
                        return
                    }

                    templateToDelete = selected
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedTemplate == nil || selectedTemplate?.isBuiltIn == true)
                .help("Delete template")

                Spacer()

                Button {
                    TemplateFileManager.revealTemplatesFolder()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Reveal templates folder")

                Button("Preview") {
                    guard let selected = selectedTemplate else { return }
                    openPreview(for: selected)
                }
                .disabled(selectedTemplate == nil)

                Button("Edit") {
                    guard let selected = selectedTemplate else { return }
                    openEditor(for: selected)
                }
                .disabled(selectedTemplate == nil)
            }
            .controlSize(.small)
            .padding(8)
        }
        .alert("Delete Template", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    deleteTemplate(template)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(templateToDelete?.name ?? "")\"? This cannot be undone.")
        }
    }

    @ViewBuilder
    private func templateContextMenu(for template: InvoiceTemplate) -> some View {
        Button("Preview") {
            openPreview(for: template)
        }

        Button("Edit") {
            openEditor(for: template)
        }

        Button("Duplicate") {
            duplicateTemplate(template)
        }

        if !template.isBuiltIn {
            Divider()

            Button("Open in External Editor") {
                if !TemplateFileManager.filesExist(for: template.id) {
                    TemplateFileManager.save(
                        html: template.resolvedHTMLContent(),
                        css: template.resolvedCSSContent(),
                        for: template.id,
                        name: template.name
                    )
                }
                TemplateFileManager.openInEditor(for: template.id)
            }

            Button("Reveal in Finder") {
                if !TemplateFileManager.filesExist(for: template.id) {
                    TemplateFileManager.save(
                        html: template.resolvedHTMLContent(),
                        css: template.resolvedCSSContent(),
                        for: template.id,
                        name: template.name
                    )
                }
                TemplateFileManager.revealInFinder(for: template.id)
            }

            Divider()

            Button("Delete", role: .destructive) {
                templateToDelete = template
                showDeleteConfirmation = true
            }
        }
    }

    private func createTemplate() {
        let html = "<div class=\"invoice\">\n    <h1>{{creditor.name}}</h1>\n    <p>Invoice {{invoice.number}}</p>\n</div>"
        let css = ".invoice {\n    padding: 40px;\n    font-family: sans-serif;\n}"

        let template = InvoiceTemplate(
            name: "Untitled Template",
            htmlContent: "",
            cssContent: ""
        )
        modelContext.insert(template)
        try? modelContext.save()

        TemplateFileManager.save(html: html, css: css, for: template.id, name: template.name)

        selectedTemplate = template
        openEditor(for: template)
    }

    private func duplicateTemplate(_ template: InvoiceTemplate) {
        let resolvedHTML = template.resolvedHTMLContent()
        let resolvedCSS = template.resolvedCSSContent()

        let copy = template.duplicate()
        modelContext.insert(copy)
        try? modelContext.save()

        if !copy.isBuiltIn {
            TemplateFileManager.save(html: resolvedHTML, css: resolvedCSS, for: copy.id, name: copy.name)
            // Clear SwiftData content — disk is source of truth
            copy.htmlContent = ""
            copy.cssContent = ""
            try? modelContext.save()
        }

        selectedTemplate = copy
    }

    private func deleteTemplate(_ template: InvoiceTemplate) {
        if selectedTemplate == template {
            selectedTemplate = nil
        }
        TemplateFileManager.delete(for: template.id)
        modelContext.delete(template)
        try? modelContext.save()
    }

    private func openEditor(for template: InvoiceTemplate) {
        editorControllers.removeAll { $0.window == nil || !$0.window!.isVisible }

        let viewModel = TemplateEditorViewModel(template: template, modelContext: modelContext)
        let editorView = TemplateEditorView(viewModel: viewModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = template.isBuiltIn ? "\(template.name) (Built-in — Read Only)" : template.name
        window.contentView = NSHostingView(rootView: editorView)

        let controller = NSWindowController(window: window)
        editorControllers.append(controller)
        controller.showWindow(nil)
        window.center()
    }

    private func openPreview(for template: InvoiceTemplate) {
        previewControllers.removeAll { $0.window == nil || !$0.window!.isVisible }

        var context = TemplateContext.sampleDictionary()
        if let userLogo = LogoStorage.dataURI() {
            var creditor = context["creditor"] as! [String: Any]
            creditor["logo"] = userLogo
            creditor["hasLogo"] = true
            context["creditor"] = creditor
        }

        let processedHTML = TemplateEngine.render(template.resolvedHTMLContent(), with: context)
        let css = template.resolvedCSSContent() + "\n" + template.columnVisibility.cssVariables()
        let html = """
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
            \(processedHTML)
            </body>
            </html>
            """

        let previewView = TemplatePreviewView(html: html)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 900),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preview — \(template.name)"
        window.contentView = NSHostingView(rootView: previewView)

        let controller = NSWindowController(window: window)
        previewControllers.append(controller)
        controller.showWindow(nil)
        window.center()
    }
}

private struct TemplateRow: View {
    let template: InvoiceTemplate

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .fontWeight(.medium)

                    if template.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }

                Text("Updated \(template.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
