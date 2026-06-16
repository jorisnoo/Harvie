//
//  ExportView.swift
//  Harvie
//

import SwiftUI

struct ExportView: View {
    @State private var viewModel = ExportViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            folderSection
            Divider()
            resourcesSection
            Spacer(minLength: 8)
            footer
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 600, idealHeight: 640)
        .task {
            await viewModel.checkCredentials()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Strings.DataExport.windowTitle)
                .font(.title2)
                .fontWeight(.semibold)
            Text(Strings.DataExport.intro)
                .font(.callout)
                .foregroundStyle(.secondary)
            if !viewModel.credentialsAvailable {
                Label(Strings.DataExport.needsCredentials, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Folder section

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Strings.DataExport.outputFolder)
                .font(.headline)
            HStack {
                Text(viewModel.outputFolder?.path ?? Strings.DataExport.noFolderSelected)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(viewModel.outputFolder == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(Strings.DataExport.chooseFolder) {
                    viewModel.pickFolder()
                }
                .disabled(viewModel.isExporting)
            }
        }
    }

    // MARK: - Resources section

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Strings.DataExport.resourcesSection)
                    .font(.headline)
                Spacer()
                Button(Strings.DataExport.selectAll) { viewModel.selectAll() }
                    .buttonStyle(.link)
                    .disabled(viewModel.isExporting)
                Button(Strings.DataExport.selectNone) { viewModel.selectNone() }
                    .buttonStyle(.link)
                    .disabled(viewModel.isExporting)
            }

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(HarvestExporter.Resource.allCases) { resource in
                        Toggle(resource.displayName, isOn: Binding(
                            get: { viewModel.isSelected(resource) },
                            set: { _ in viewModel.toggle(resource) }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 260)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .disabled(viewModel.isExporting)

            Text(Strings.DataExport.formatNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isExporting || !viewModel.progressMessage.isEmpty {
                progressBlock
            }

            if let error = viewModel.error {
                Label(Strings.DataExport.failureSummary(error), systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                if let summary = viewModel.lastSummary, !viewModel.isExporting {
                    Button(Strings.DataExport.revealInFinder) {
                        viewModel.revealLastExport()
                    }
                    failureChip(summary: summary)
                }

                Spacer()

                if viewModel.isExporting {
                    Button(Strings.DataExport.cancel) {
                        viewModel.cancelExport()
                    }
                }

                Button(viewModel.isExporting ? Strings.DataExport.exportRunning : Strings.DataExport.startExport) {
                    viewModel.startExport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canStartExport)
            }
        }
    }

    @ViewBuilder
    private func failureChip(summary: HarvestExporter.Summary) -> some View {
        if summary.hasFailures {
            Label("\(summary.results.count - summary.successfulResources) failed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: viewModel.progress)
            Text(viewModel.progressMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    ExportView()
}
