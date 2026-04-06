//
//  ClientOverridesSettings.swift
//  Harvie
//

import SwiftData
import SwiftUI

struct ClientOverridesSettings: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClientOverride.clientName) private var overrides: [ClientOverride]
    @Query private var cachedInvoices: [CachedInvoice]

    @State private var selectedClientId: Int?
    @State private var showLabelEditor = false

    private var availableClients: [ClientReference] {
        var seen = Set<Int>()
        return cachedInvoices.compactMap { invoice in
            guard seen.insert(invoice.clientId).inserted else { return nil }
            return ClientReference(id: invoice.clientId, name: invoice.clientName)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var clientsWithoutOverride: [ClientReference] {
        let overrideIds = Set(overrides.map(\.clientId))
        return availableClients.filter { !overrideIds.contains($0.id) }
    }

    private var selectedOverride: ClientOverride? {
        guard let id = selectedClientId else { return nil }
        return overrides.first { $0.clientId == id }
    }

    private var appSettings: AppSettings {
        AppSettingsStorage.load()
    }

    var body: some View {
        Form {
            Section(Strings.Settings.clientOverrides) {
                if overrides.isEmpty && availableClients.isEmpty {
                    Text(Strings.Settings.noClientsHint)
                        .foregroundStyle(.secondary)
                } else if overrides.isEmpty {
                    Text(Strings.Settings.noOverridesHint)
                        .foregroundStyle(.secondary)
                }

                if !overrides.isEmpty {
                    Picker(Strings.Settings.selectClient, selection: $selectedClientId) {
                        Text(Strings.Settings.selectClient).tag(nil as Int?)
                        ForEach(overrides, id: \.clientId) { override in
                            Text(override.clientName).tag(override.clientId as Int?)
                        }
                    }
                }

                if !clientsWithoutOverride.isEmpty {
                    Menu(Strings.Settings.addOverride) {
                        ForEach(clientsWithoutOverride) { client in
                            Button(client.name) {
                                addOverride(for: client)
                            }
                        }
                    }
                }
            }

            if let override = selectedOverride {
                overrideFields(for: override)
            }
        }
        .formStyle(.grouped)
        .onChange(of: overrides.count) {
            // Auto-select if only one override exists
            if overrides.count == 1 {
                selectedClientId = overrides.first?.clientId
            }
            // Clear selection if selected override was deleted
            if let id = selectedClientId, !overrides.contains(where: { $0.clientId == id }) {
                selectedClientId = nil
            }
        }
    }

    @ViewBuilder
    private func overrideFields(for override: ClientOverride) -> some View {
        Section(Strings.Settings.settingsFor(override.clientName)) {
            // Language
            Toggle(Strings.Settings.overrideLanguage, isOn: languageBinding(for: override))

            if override.templateLanguage != nil {
                Picker(Strings.Settings.language, selection: languagePickerBinding(for: override)) {
                    ForEach(TemplateLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            // Column visibility
            Toggle(Strings.Settings.overrideColumnVisibility, isOn: columnVisibilityBinding(for: override))

            if override.columnVisibility != nil {
                Toggle(Strings.Settings.showQuantityColumn, isOn: columnFieldBinding(for: override, keyPath: \.showQuantity))
                Toggle(Strings.Settings.showUnitPriceColumn, isOn: columnFieldBinding(for: override, keyPath: \.showUnitPrice))
                Toggle(Strings.Settings.showTotalHours, isOn: columnFieldBinding(for: override, keyPath: \.showTotalHours))
            }

            // Labels
            Toggle(Strings.Settings.overrideLabels, isOn: labelsBinding(for: override))

            if override.labelOverrides != nil {
                Button(Strings.Settings.customizeLabels) {
                    showLabelEditor = true
                }
            }
        }
        .sheet(isPresented: $showLabelEditor) {
            LabelEditorSheet(labelOverrides: labelOverridesBinding(for: override))
        }

        Section {
            Button(Strings.Settings.removeOverride, role: .destructive) {
                removeOverride(override)
            }
        }
    }

    // MARK: - Bindings

    private func languageBinding(for override: ClientOverride) -> Binding<Bool> {
        Binding(
            get: { override.templateLanguage != nil },
            set: { enabled in
                override.templateLanguage = enabled ? appSettings.templateLanguage : nil
            }
        )
    }

    private func languagePickerBinding(for override: ClientOverride) -> Binding<TemplateLanguage> {
        Binding(
            get: { override.templateLanguage ?? appSettings.templateLanguage },
            set: { override.templateLanguage = $0 }
        )
    }

    private func columnVisibilityBinding(for override: ClientOverride) -> Binding<Bool> {
        Binding(
            get: { override.columnVisibility != nil },
            set: { enabled in
                override.columnVisibility = enabled ? appSettings.columnVisibility : nil
            }
        )
    }

    private func columnFieldBinding(for override: ClientOverride, keyPath: WritableKeyPath<ColumnVisibility, Bool>) -> Binding<Bool> {
        Binding(
            get: { (override.columnVisibility ?? appSettings.columnVisibility)[keyPath: keyPath] },
            set: { newValue in
                var cv = override.columnVisibility ?? appSettings.columnVisibility
                cv[keyPath: keyPath] = newValue
                override.columnVisibility = cv
            }
        )
    }

    private func labelsBinding(for override: ClientOverride) -> Binding<Bool> {
        Binding(
            get: { override.labelOverrides != nil },
            set: { enabled in
                override.labelOverrides = enabled ? (appSettings.labelOverrides ?? [:]) : nil
            }
        )
    }

    private func labelOverridesBinding(for override: ClientOverride) -> Binding<[String: [String: String]]?> {
        Binding(
            get: { override.labelOverrides },
            set: { override.labelOverrides = $0 }
        )
    }

    // MARK: - Actions

    private func addOverride(for client: ClientReference) {
        let override = ClientOverride(clientId: client.id, clientName: client.name)
        modelContext.insert(override)
        selectedClientId = client.id
    }

    private func removeOverride(_ override: ClientOverride) {
        selectedClientId = nil
        modelContext.delete(override)
    }
}
