//
//  LabelEditorSheet.swift
//  Harvie
//

import SwiftUI

struct LabelEditorSheet: View {
    @Binding var labelOverrides: [String: [String: String]]?
    @State private var selectedLanguage: TemplateLanguage = .en
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 550, height: 600)
    }

    private var header: some View {
        HStack {
            Text(Strings.LabelEditor.title)
                .font(.headline)
            Spacer()
            Picker("", selection: $selectedLanguage) {
                ForEach(TemplateLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
        .padding()
    }

    private var form: some View {
        Form {
            Section(Strings.LabelEditor.templateLabels) {
                ForEach(TemplateLanguage.templateLabelKeys, id: \.self) { key in
                    LabelRow(
                        key: key,
                        language: selectedLanguage,
                        labelOverrides: $labelOverrides
                    )
                }
            }

            Section(Strings.LabelEditor.qrBillLabels) {
                ForEach(TemplateLanguage.qrBillLabelKeys, id: \.self) { key in
                    LabelRow(
                        key: key,
                        language: selectedLanguage,
                        labelOverrides: $labelOverrides
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        HStack {
            Button(Strings.LabelEditor.resetLanguage) {
                labelOverrides?[selectedLanguage.rawValue] = nil
                if labelOverrides?.isEmpty == true {
                    labelOverrides = nil
                }
            }
            .disabled(labelOverrides?[selectedLanguage.rawValue] == nil)

            Spacer()

            Button(Strings.Common.done) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}

private struct LabelRow: View {
    let key: String
    let language: TemplateLanguage
    @Binding var labelOverrides: [String: [String: String]]?

    private var defaultValue: String {
        language.defaultValue(for: key)
    }

    private var displayKey: String {
        key.hasPrefix("qr.") ? String(key.dropFirst(3)) : key
    }

    private var isCustomized: Bool {
        if let v = labelOverrides?[language.rawValue]?[key], !v.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        LabeledContent(displayKey) {
            HStack(spacing: 4) {
                TextField("", text: binding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                if isCustomized {
                    Button {
                        setOverride(nil)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(Strings.LabelEditor.resetToDefault)
                }
            }
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { labelOverrides?[language.rawValue]?[key] ?? defaultValue },
            set: { newValue in
                let trimmed = newValue.isEmpty || newValue == defaultValue ? nil : newValue
                setOverride(trimmed)
            }
        )
    }

    private func setOverride(_ value: String?) {
        if let value {
            if labelOverrides == nil { labelOverrides = [:] }
            if labelOverrides?[language.rawValue] == nil { labelOverrides?[language.rawValue] = [:] }
            labelOverrides?[language.rawValue]?[key] = value
        } else {
            labelOverrides?[language.rawValue]?.removeValue(forKey: key)
            if labelOverrides?[language.rawValue]?.isEmpty == true {
                labelOverrides?[language.rawValue] = nil
            }
            if labelOverrides?.isEmpty == true {
                labelOverrides = nil
            }
        }
    }
}
