//
//  SettingsView.swift
//  Harvester
//

import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case harvest
    case qrBill
    case downloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .harvest: "Harvest"
        case .qrBill: "QR Bill"
        case .downloads: "Downloads"
        }
    }

    var icon: String {
        switch self {
        case .harvest: "cloud"
        case .qrBill: "qrcode"
        case .downloads: "folder"
        }
    }
}

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var selection: SettingsSection? = .harvest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(180)
            .navigationTitle("Settings")
        } detail: {
            if let section = selection {
                SettingsDetail(section: section, viewModel: viewModel)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    Task {
                        await viewModel.saveSettings()
                        if viewModel.saveError == nil {
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isSaving)
            }
            .padding()
            .background(.bar)
        }
        .task {
            await viewModel.loadSettings()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK") { viewModel.saveError = nil }
        } message: {
            Text(viewModel.saveError ?? "")
        }
    }
}

// MARK: - Settings Detail

struct SettingsDetail: View {
    let section: SettingsSection
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        switch section {
        case .harvest:
            HarvestSettings(viewModel: viewModel)
        case .qrBill:
            QRBillSettings(viewModel: viewModel)
        case .downloads:
            DownloadsSettings(viewModel: viewModel)
        }
    }
}

// MARK: - Harvest Settings

struct HarvestSettings: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("API Credentials") {
                LabeledContent("Access Token") {
                    SecureField("", text: $viewModel.harvestCredentials.accessToken)
                        .textContentType(.password)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Account ID") {
                    TextField("", text: $viewModel.harvestCredentials.accountId)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Subdomain") {
                    TextField("", text: $viewModel.harvestCredentials.subdomain)
                        .textContentType(.URL)
                        .multilineTextAlignment(.trailing)
                }
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

// MARK: - QR Bill Settings

struct QRBillSettings: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Creditor Information") {
                LabeledContent("IBAN") {
                    TextField("", text: $viewModel.creditorInfo.iban)
                        .textContentType(.creditCardNumber)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Name") {
                    TextField("", text: $viewModel.creditorInfo.name)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Address") {
                LabeledContent("Street") {
                    TextField("", text: $viewModel.creditorInfo.streetName)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Number") {
                    TextField("", text: $viewModel.creditorInfo.buildingNumber)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("ZIP") {
                    TextField("", text: $viewModel.creditorInfo.postalCode)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("City") {
                    TextField("", text: $viewModel.creditorInfo.town)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Country") {
                    TextField("", text: $viewModel.creditorInfo.country)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
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

// MARK: - Downloads Settings

struct DownloadsSettings: View {
    @Bindable var viewModel: SettingsViewModel

    private var filenamePreview: String {
        viewModel.appSettings.generateFilename(
            invoiceNumber: "2024-001",
            creditorName: viewModel.creditorInfo.name.isEmpty ? "Company" : viewModel.creditorInfo.name,
            clientName: "Example Client",
            date: Date(),
            issueDate: Date(),
            dueDate: Date(),
            paidDate: Date()
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
                    LabeledContent("Folder") {
                        HStack {
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
            }

            Section("Filename") {
                LabeledContent("Pattern") {
                    TextField("", text: $viewModel.appSettings.filenamePattern)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Preview") {
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
                    Text("{date} - Date based on sort (YYYYMMDD)")
                    Text("{issueDate} - Issue date (YYYYMMDD)")
                    Text("{dueDate} - Due date (YYYYMMDD)")
                    Text("{paidDate} - Paid date (YYYYMMDD)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Demo") {
                Toggle("Demo Mode", isOn: $viewModel.appSettings.isDemoMode)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
