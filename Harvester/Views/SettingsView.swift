//
//  SettingsView.swift
//  Harvester
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Harvest API") {
                SecureField("Access Token", text: $viewModel.harvestCredentials.accessToken)
                    .textContentType(.password)

                TextField("Account ID", text: $viewModel.harvestCredentials.accountId)

                TextField("Subdomain", text: $viewModel.harvestCredentials.subdomain)
                    .textContentType(.URL)

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
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .help(message)
                        }
                    }
                }
            }

            Section("Creditor Information (QR Bill)") {
                TextField("IBAN", text: $viewModel.creditorInfo.iban)
                    .textContentType(.creditCardNumber)

                TextField("Name / Company", text: $viewModel.creditorInfo.name)

                TextField("Street", text: $viewModel.creditorInfo.streetName)

                TextField("Building Number", text: $viewModel.creditorInfo.buildingNumber)

                HStack {
                    TextField("Postal Code", text: $viewModel.creditorInfo.postalCode)
                        .frame(width: 100)

                    TextField("Town", text: $viewModel.creditorInfo.town)
                }

                TextField("Country Code", text: $viewModel.creditorInfo.country)
                    .frame(width: 60)
            }

            Section("Downloads") {
                Picker("Save behavior", selection: $viewModel.appSettings.downloadBehavior) {
                    ForEach(DownloadBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)

                if viewModel.appSettings.downloadBehavior == .useDefaultFolder {
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

            if let error = viewModel.saveError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 450, minHeight: 550)
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
    }
}

#Preview {
    SettingsView()
}
