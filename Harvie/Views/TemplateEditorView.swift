//
//  TemplateEditorView.swift
//  HarvestQRBill
//

import SwiftUI

struct TemplateEditorView: View {
    @State var viewModel: TemplateEditorViewModel
    @AppStorage("showVariablesPanel") private var showVariablesPanel = true
    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            HSplitView {
                editorPanel
                    .frame(minWidth: 400)

                PreviewPanel(viewModel: viewModel)
                    .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField(Strings.Templates.templateName, text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .disabled(viewModel.isBuiltIn)

            Spacer()

            if viewModel.isBuiltIn {
                Label(Strings.Templates.readOnly, systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.isBuiltIn {
                Button {
                    viewModel.openInExternalEditor()
                } label: {
                    Label(Strings.Templates.openInEditor, systemImage: "rectangle.portrait.and.arrow.right")
                }
                .controlSize(.small)
            }

            Toggle(isOn: $showVariablesPanel) {
                Label(Strings.Templates.variables, systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .toggleStyle(.button)
            .controlSize(.small)

            if viewModel.isDirty {
                Button(Strings.Common.save) {
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

}

private struct PreviewPanel: View {
    let viewModel: TemplateEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Strings.Common.preview)
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
                .help(Strings.Templates.refreshPreview)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            TemplatePreviewView(html: viewModel.previewHTML)
        }
        .background(.white)
    }
}
