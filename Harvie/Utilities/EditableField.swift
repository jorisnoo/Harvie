//
//  EditableField.swift
//  Harvie
//

import SwiftUI

struct EditableField<Value: Equatable & Sendable>: DynamicProperty, Sendable {
    @State var current: Value
    @State var lastSaved: Value
    @State var isSaving: Bool = false
    @State var showSaved: Bool = false
    @State var clearSavedTask: Task<Void, Never>?

    var isModified: Bool { current != lastSaved }

    init(_ initialValue: Value) {
        _current = State(initialValue: initialValue)
        _lastSaved = State(initialValue: initialValue)
    }

    var binding: Binding<Value> {
        Binding(
            get: { current },
            set: { newValue in
                current = newValue
                showSaved = false
            }
        )
    }

    func reset(to value: Value) {
        current = value
        lastSaved = value
        showSaved = false
    }

    func markSaving() { isSaving = true }

    func markSaved() {
        lastSaved = current
        showSaved = true
        isSaving = false
        clearSavedTask?.cancel()
        clearSavedTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showSaved = false
        }
    }

    func markFailed() { isSaving = false }
}
