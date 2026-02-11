//
//  TemplateEditorView.swift
//  HarvestQRBill
//

import SwiftUI

struct TemplateEditorView: View {
    @State var viewModel: TemplateEditorViewModel
    @State private var showVariablesPanel = true

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

            if viewModel.isBuiltIn {
                Label("Read Only", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        HTMLEditorView(text: $viewModel.htmlContent) {
                            viewModel.contentChanged()
                        }
                    case .css:
                        HTMLEditorView(text: $viewModel.cssContent) {
                            viewModel.contentChanged()
                        }
                    }
                }
                .disabled(viewModel.isBuiltIn)

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
