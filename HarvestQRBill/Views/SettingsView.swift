//
//  SettingsView.swift
//  HarvestQRBill
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            HarvestSettings(viewModel: viewModel)
                .tabItem { Label("Harvest", systemImage: "cloud") }

            QRBillSettings(viewModel: viewModel)
                .tabItem { Label("QR Bill", systemImage: "qrcode") }

            DownloadsSettings(viewModel: viewModel)
                .tabItem { Label("Downloads", systemImage: "folder") }

            if FeatureFlags.customPDFTemplates {
                TemplatesSettings(viewModel: viewModel)
                    .tabItem { Label("Templates (Beta)", systemImage: "doc.richtext") }
            }

            FeedbackSettings()
                .tabItem { Label("Feedback", systemImage: "bubble.left.and.text.bubble.right") }
        }
        .frame(minWidth: 500, minHeight: 550)
        .task {
            await viewModel.loadSettings()
        }
        .onChange(of: viewModel.harvestCredentials) { viewModel.autoSave() }
        .onChange(of: viewModel.creditorInfo) { viewModel.autoSave() }
        .onChange(of: viewModel.appSettings) { viewModel.autoSave() }
        .onDisappear { viewModel.saveImmediately() }
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
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        Task {
                            await viewModel.testConnection()
                        }
                    }
                    .disabled(viewModel.isTestingConnection || !viewModel.harvestCredentials.canTestConnection)

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

                if !viewModel.harvestCredentials.subdomain.isEmpty {
                    LabeledContent("Subdomain") {
                        Text(viewModel.harvestCredentials.subdomain)
                            .foregroundStyle(.secondary)
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

                LabeledContent("Date format") {
                    TextField("", text: $viewModel.appSettings.dateFormat)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
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
                    Text("{date} - Date based on sort")
                    Text("{issueDate} - Issue date")
                    Text("{dueDate} - Due date")
                    Text("{paidDate} - Paid date")

                    Text("Date format components:")
                        .fontWeight(.medium)
                        .padding(.top, 4)
                    Text("YYYY (4-digit year), YY (2-digit year), MM (month), DD (day)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            #if DEBUG
            Section("Demo") {
                Toggle("Demo Mode", isOn: $viewModel.appSettings.isDemoMode)
            }
            #endif
        }
        .formStyle(.grouped)
    }
}

// MARK: - Templates Settings

struct TemplatesSettings: View {
    @Bindable var viewModel: SettingsViewModel
    @Query(sort: \InvoiceTemplate.name) private var templates: [InvoiceTemplate]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Company Logo") {
                    HStack {
                        if let logo = viewModel.logoImage {
                            Image(nsImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 48)
                        } else {
                            Text("No logo set")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            Button("Choose Image...") {
                                viewModel.selectLogo()
                            }

                            if viewModel.logoImage != nil {
                                Button("Remove", role: .destructive) {
                                    viewModel.removeLogo()
                                }
                            }
                        }
                    }
                }

                Section("Invoice PDF Source") {
                    Picker("PDF source", selection: $viewModel.appSettings.pdfSource) {
                        ForEach(InvoicePDFSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    if viewModel.appSettings.pdfSource == .template {
                        Picker("Template", selection: $viewModel.appSettings.selectedTemplateId) {
                            ForEach(templates) { template in
                                Text(template.name).tag(template.id as UUID?)
                            }
                        }
                        .onAppear {
                            if viewModel.appSettings.selectedTemplateId == nil,
                               let first = templates.first {
                                viewModel.appSettings.selectedTemplateId = first.id
                            }
                        }
                        .onChange(of: templates) {
                            if viewModel.appSettings.selectedTemplateId == nil,
                               let first = templates.first {
                                viewModel.appSettings.selectedTemplateId = first.id
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)

            TemplateListView()
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Feedback Settings

struct FeedbackSettings: View {
    var body: some View {
        Form {
            Section("Contact") {
                Link(destination: URL(string: "mailto:contact@noordermeer.ch")!) {
                    Label("contact@noordermeer.ch", systemImage: "envelope")
                }

                Text("Send us an email with questions, suggestions, or feedback.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Report an Issue") {
                Link(destination: URL(string: "https://github.com/jorisnoo/HarvestQRBill/issues")!) {
                    Label("Open GitHub Issues", systemImage: "exclamationmark.bubble")
                }

                Text("Report bugs or request features on GitHub.")
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
