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
            Section {
                SecureField("Access Token", text: $viewModel.harvestCredentials.accessToken)
                    .textContentType(.password)

                TextField("Account ID", text: $viewModel.harvestCredentials.accountId)

                TextField("Subdomain", text: $viewModel.harvestCredentials.subdomain)
                    .textContentType(.URL)
            } header: {
                Text("API Credentials")
            } footer: {
                Text("Get your API credentials from Harvest Developer Tools.")
                    .foregroundStyle(.secondary)
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
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - QR Bill Settings Tab

struct QRBillSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                LabeledContent("IBAN") {
                    TextField("CH00 0000 0000 0000 0000 0", text: $viewModel.creditorInfo.iban)
                        .textContentType(.creditCardNumber)
                }

                LabeledContent("Name") {
                    TextField("Company or Person Name", text: $viewModel.creditorInfo.name)
                }
            } header: {
                Text("Creditor Information")
            } footer: {
                Text("This information appears on the QR bill as the payment recipient.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Street") {
                    HStack {
                        TextField("Street name", text: $viewModel.creditorInfo.streetName)
                        TextField("Nr.", text: $viewModel.creditorInfo.buildingNumber)
                            .frame(width: 60)
                    }
                }

                LabeledContent("City") {
                    HStack {
                        TextField("ZIP", text: $viewModel.creditorInfo.postalCode)
                            .frame(width: 70)
                        TextField("City", text: $viewModel.creditorInfo.town)
                    }
                }

                LabeledContent("Country") {
                    TextField("CH", text: $viewModel.creditorInfo.country)
                        .frame(width: 50)
                }
            } header: {
                Text("Address")
            }
        }
        .formStyle(.grouped)
        .padding()
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
            Section {
                Picker("Save behavior", selection: $viewModel.appSettings.downloadBehavior) {
                    ForEach(DownloadBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)

                if viewModel.appSettings.downloadBehavior == .useDefaultFolder {
                    LabeledContent("Folder") {
                        HStack {
                            Text(viewModel.appSettings.defaultDownloadPath ?? "Not set")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Choose...") {
                                viewModel.selectDownloadFolder()
                            }
                        }
                    }
                }
            } header: {
                Text("Save Location")
            }

            Section {
                LabeledContent("Pattern") {
                    TextField("Rechnung_{number}_{creditor}", text: $viewModel.appSettings.filenamePattern)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("Preview") {
                    Text(filenamePreview)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("Filename")
            } footer: {
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
        .padding()
    }
}

#Preview {
    SettingsView()
}
