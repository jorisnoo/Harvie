//
//  TemplateEditorView.swift
//  HarvestQRBill
//

import SwiftUI

struct TemplateEditorView: View {
    @State var viewModel: TemplateEditorViewModel
    @AppStorage("showVariablesPanel") private var showVariablesPanel = true
    @State private var showColumnsInfo = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            HSplitView {
                editorPanel
                    .frame(minWidth: 400)

                previewPanel
                    .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("Template Name", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .disabled(viewModel.isBuiltIn)

            Spacer()

            columnsSection

            if viewModel.isBuiltIn {
                Label("Read Only", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.isBuiltIn {
                Button {
                    viewModel.openInExternalEditor()
                } label: {
                    Label("Open in Editor", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .controlSize(.small)
            }

            Toggle(isOn: $showVariablesPanel) {
                Label("Variables", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .toggleStyle(.button)
            .controlSize(.small)

            if viewModel.isDirty {
                Button("Save") {
                    viewModel.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isBuiltIn)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var columnsSection: some View {
        HStack(spacing: 8) {
            Text("Columns:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showColumnsInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .controlSize(.small)
            .popover(isPresented: $showColumnsInfo) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Column Visibility")
                        .font(.headline)

                    Text("Controls which columns appear in the invoice line items table. This setting is saved per template.")

                    Text("How it works")
                        .font(.subheadline.bold())
                        .padding(.top, 2)

                    Text("Each toggle maps to a CSS variable (e.g. `--col-qty-display`) injected into the template. Templates use these via `var(--col-qty-display)` to show or hide columns. Custom templates can reference these same variables.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .frame(width: 280)
                .padding()
            }

            Toggle("Qty", isOn: $viewModel.columnVisibility.showQuantity)
                .onChange(of: viewModel.columnVisibility.showQuantity) {
                    viewModel.columnVisibilityChanged()
                }

            Toggle("Price", isOn: $viewModel.columnVisibility.showUnitPrice)
                .onChange(of: viewModel.columnVisibility.showUnitPrice) {
                    viewModel.columnVisibilityChanged()
                }

            Toggle("Hours", isOn: $viewModel.columnVisibility.showTotalHours)
                .onChange(of: viewModel.columnVisibility.showTotalHours) {
                    viewModel.columnVisibilityChanged()
                }
        }
        .toggleStyle(.checkbox)
        .controlSize(.small)
    }

    private var editorPanel: some View {
        VStack(spacing: 0) {
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(TemplateEditorViewModel.EditorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            HStack(spacing: 0) {
                Group {
                    switch viewModel.selectedTab {
                    case .html:
                        HTMLEditorView(text: $viewModel.htmlContent, isEditable: !viewModel.isBuiltIn) {
                            viewModel.contentChanged()
                        }
                    case .css:
                        HTMLEditorView(text: $viewModel.cssContent, isEditable: !viewModel.isBuiltIn) {
                            viewModel.contentChanged()
                        }
                    }
                }

                if showVariablesPanel {
                    Divider()

                    TemplateVariablesPanel { variable in
                        viewModel.insertVariable(variable)
                    }
                    .frame(width: 180)
                    .disabled(viewModel.isBuiltIn)
                }
            }
        }
    }

    private var previewPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.updatePreview()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Refresh preview")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            TemplatePreviewView(html: viewModel.previewHTML)
        }
        .background(.white)
    }
}
