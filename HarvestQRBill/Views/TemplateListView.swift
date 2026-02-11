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

                Button("Edit") {
                    guard let selected = selectedTemplate else { return }
                    openEditor(for: selected)
                }
                .disabled(selectedTemplate == nil)
            }
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
        Button("Edit") {
            openEditor(for: template)
        }

        Button("Duplicate") {
            duplicateTemplate(template)
        }

        if !template.isBuiltIn {
            Divider()
            Button("Delete", role: .destructive) {
                templateToDelete = template
                showDeleteConfirmation = true
            }
        }
    }

    private func createTemplate() {
        let template = InvoiceTemplate(
            name: "Untitled Template",
            htmlContent: "<div class=\"invoice\">\n    <h1>{{creditor.name}}</h1>\n    <p>Invoice {{invoice.number}}</p>\n</div>",
            cssContent: ".invoice {\n    padding: 40px;\n    font-family: sans-serif;\n}"
        )
        modelContext.insert(template)
        try? modelContext.save()
        selectedTemplate = template
        openEditor(for: template)
    }

    private func duplicateTemplate(_ template: InvoiceTemplate) {
        let copy = template.duplicate()
        modelContext.insert(copy)
        try? modelContext.save()
        selectedTemplate = copy
    }

    private func deleteTemplate(_ template: InvoiceTemplate) {
        if selectedTemplate == template {
            selectedTemplate = nil
        }
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
