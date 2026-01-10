//
//  SettingsView.swift
//  Harvester
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            HarvestSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Harvest", systemImage: "cloud")
                }

            QRBillSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("QR Bill", systemImage: "qrcode")
                }

            DownloadsSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Downloads", systemImage: "folder")
                }
        }
        .frame(minWidth: 500, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.saveSettings()
                        if viewModel.saveError == nil {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .task {
            await viewModel.loadSettings()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK") { viewModel.saveError = nil }
        } message: {
            Text(viewModel.saveError ?? "")
        }
    }
}

// MARK: - Harvest Settings Tab

struct HarvestSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("API Credentials") {
                SecureField("Access Token", text: $viewModel.harvestCredentials.accessToken)
                    .textContentType(.password)

                TextField("Account ID", text: $viewModel.harvestCredentials.accountId)

                TextField("Subdomain", text: $viewModel.harvestCredentials.subdomain)
                    .textContentType(.URL)
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        Task {
                            await viewModel.testConnection()
                        }
                    }
                    .disabled(viewModel.isTestingConnection || !viewModel.harvestCredentials.isValid)

                    if viewModel.isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    if let result = viewModel.connectionTestResult {
                        switch result {
                        case .success:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label("Failed", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .help(message)
                        }
                    }
                }
            }

            Section {
                Text("Get your API credentials from Harvest Developer Tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - QR Bill Settings Tab

struct QRBillSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Creditor Information") {
                TextField("IBAN", text: $viewModel.creditorInfo.iban)
                    .textContentType(.creditCardNumber)

                TextField("Name", text: $viewModel.creditorInfo.name)
            }

            Section("Address") {
                HStack {
                    TextField("Street", text: $viewModel.creditorInfo.streetName)
                    TextField("Nr.", text: $viewModel.creditorInfo.buildingNumber)
                        .frame(width: 60)
                }

                HStack {
                    TextField("ZIP", text: $viewModel.creditorInfo.postalCode)
                        .frame(width: 80)
                    TextField("City", text: $viewModel.creditorInfo.town)
                }

                TextField("Country", text: $viewModel.creditorInfo.country)
                    .frame(width: 80)
            }

            Section {
                Text("This information appears on the QR bill as the payment recipient.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Downloads Settings Tab

struct DownloadsSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    private var filenamePreview: String {
        viewModel.appSettings.generateFilename(
            invoiceNumber: "2024-001",
            creditorName: viewModel.creditorInfo.name.isEmpty ? "Company" : viewModel.creditorInfo.name,
            clientName: "Example Client",
            issueDate: Date()
        )
    }

    var body: some View {
        Form {
            Section("Save Location") {
                Picker("Save behavior", selection: $viewModel.appSettings.downloadBehavior) {
                    ForEach(DownloadBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)

                if viewModel.appSettings.downloadBehavior == .useDefaultFolder {
                    HStack {
                        Text("Folder")
                        Spacer()
                        Text(viewModel.appSettings.defaultDownloadPath ?? "Not set")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose...") {
                            viewModel.selectDownloadFolder()
                        }
                    }
                }
            }

            Section("Filename") {
                TextField("Pattern", text: $viewModel.appSettings.filenamePattern)
                    .font(.system(.body, design: .monospaced))

                HStack {
                    Text("Preview")
                    Spacer()
                    Text(filenamePreview)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available placeholders:")
                        .fontWeight(.medium)
                    Text("{number} - Invoice number")
                    Text("{creditor} - Your company name")
                    Text("{client} - Client name")
                    Text("{date} - Issue date (YYYY-MM-DD)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
