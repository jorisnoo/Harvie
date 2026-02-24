//
//  EditableField.swift
//  HarvestQRBill
//

import SwiftUI

struct EditableField<Value: Equatable & Sendable>: DynamicProperty, Sendable {
    @State var current: Value
    @State var lastSaved: Value
    @State var isSaving: Bool = false
    @State var showSaved: Bool = false

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
    }

    func markFailed() { isSaving = false }
}
