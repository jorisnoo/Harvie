//
//  TemplateEditorViewModelTests.swift
//  HarvieTests
//

import Foundation
import SwiftData
import Testing
@testable import Harvie

@Suite("Template editor ViewModel")
@MainActor
struct TemplateEditorViewModelTests {
    // Keeps each test's in-memory store alive for as long as its view model.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: InvoiceTemplate.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeViewModel() -> TemplateEditorViewModel {
        // Built-in templates never touch the templates folder on disk.
        let template = InvoiceTemplate(name: "Original", htmlContent: "<p></p>", isBuiltIn: true)
        container.mainContext.insert(template)
        return TemplateEditorViewModel(template: template, modelContext: container.mainContext)
    }

    @Test func startsClean() {
        #expect(makeViewModel().isDirty == false)
    }

    @Test func renamingMarksDirty() {
        let vm = makeViewModel()
        vm.name = "Renamed"
        #expect(vm.isDirty)
    }

    @Test func assigningTheSameNameStaysClean() {
        let vm = makeViewModel()
        vm.name = "Original"
        #expect(vm.isDirty == false)
    }
}
