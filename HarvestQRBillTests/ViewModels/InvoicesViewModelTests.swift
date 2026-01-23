//
//  InvoicesViewModelTests.swift
//  HarvestQRBillTests
//

import Testing
@testable import HarvestQRBill

@Suite("Invoices ViewModel")
struct InvoicesViewModelTests {

    @Test("Toggle selection adds invoice ID")
    @MainActor
    func toggleSelectionAdds() {
        let vm = InvoicesViewModel()

        vm.toggleSelection(for: 123)

        #expect(vm.selectedInvoiceIDs.contains(123))
    }

    @Test("Toggle selection removes existing ID")
    @MainActor
    func toggleSelectionRemoves() {
        let vm = InvoicesViewModel()
        vm.selectedInvoiceIDs.insert(123)

        vm.toggleSelection(for: 123)

        #expect(!vm.selectedInvoiceIDs.contains(123))
    }

    @Test("Toggle selection works for multiple IDs")
    @MainActor
    func toggleSelectionMultiple() {
        let vm = InvoicesViewModel()

        vm.toggleSelection(for: 1)
        vm.toggleSelection(for: 2)
        vm.toggleSelection(for: 3)

        #expect(vm.selectedInvoiceIDs == Set([1, 2, 3]))
    }

    @Test("Enter selection mode sets flag")
    @MainActor
    func enterSelectionMode() {
        let vm = InvoicesViewModel()

        vm.enterSelectionMode()

        #expect(vm.isSelectionMode)
    }

    @Test("Exit selection mode clears flag")
    @MainActor
    func exitSelectionModeClearsFlag() {
        let vm = InvoicesViewModel()
        vm.isSelectionMode = true

        vm.exitSelectionMode()

        #expect(!vm.isSelectionMode)
    }

    @Test("Exit selection mode clears selections")
    @MainActor
    func exitSelectionModeClearsSelections() {
        let vm = InvoicesViewModel()
        vm.isSelectionMode = true
        vm.selectedInvoiceIDs = [1, 2, 3]

        vm.exitSelectionMode()

        #expect(vm.selectedInvoiceIDs.isEmpty)
    }

    @Test("Deselect all clears all selections")
    @MainActor
    func deselectAll() {
        let vm = InvoicesViewModel()
        vm.selectedInvoiceIDs = [1, 2, 3, 4, 5]

        vm.deselectAll()

        #expect(vm.selectedInvoiceIDs.isEmpty)
    }

    @Test("Sort direction toggle switches between ascending and descending")
    @MainActor
    func sortDirectionToggle() {
        var direction = SortDirection.ascending

        direction.toggle()
        #expect(direction == .descending)

        direction.toggle()
        #expect(direction == .ascending)
    }

    @Test("Default state filter is open")
    @MainActor
    func defaultStateFilter() {
        let vm = InvoicesViewModel()

        #expect(vm.stateFilter == .open)
    }

    @Test("Default sort option is issue date")
    @MainActor
    func defaultSortOption() {
        let vm = InvoicesViewModel()

        #expect(vm.sortOption == .issueDate)
    }

    @Test("Default sort direction is descending")
    @MainActor
    func defaultSortDirection() {
        let vm = InvoicesViewModel()

        #expect(vm.sortDirection == .descending)
    }

    @Test("Valid sort options for draft filter")
    @MainActor
    func validSortOptionsForDraft() {
        let vm = InvoicesViewModel()
        vm.stateFilter = .draft

        #expect(vm.validSortOptions == [.issueDate])
    }

    @Test("Valid sort options for open filter")
    @MainActor
    func validSortOptionsForOpen() {
        let vm = InvoicesViewModel()
        vm.stateFilter = .open

        #expect(vm.validSortOptions == [.issueDate, .dueDate])
    }

    @Test("Valid sort options for paid filter includes all options")
    @MainActor
    func validSortOptionsForPaid() {
        let vm = InvoicesViewModel()
        vm.stateFilter = .paid

        #expect(vm.validSortOptions == InvoiceSortOption.allCases)
    }

    @Test("All selected are drafts returns false when empty")
    @MainActor
    func allSelectedAreDraftsEmpty() {
        let vm = InvoicesViewModel()

        #expect(!vm.allSelectedAreDrafts)
    }

    @Test("All selected are open returns false when empty")
    @MainActor
    func allSelectedAreOpenEmpty() {
        let vm = InvoicesViewModel()

        #expect(!vm.allSelectedAreOpen)
    }

    @Test("Can export with QR bill when creditor info is valid")
    @MainActor
    func canExportWithQRBill() {
        let vm = InvoicesViewModel()
        vm.creditorInfo = CreditorInfo(
            iban: "CH9300762011623852957",
            name: "Test Company",
            streetName: "Test Street",
            buildingNumber: "1",
            postalCode: "8000",
            town: "Zurich",
            country: "CH"
        )

        #expect(vm.canExportWithQRBill)
    }

    @Test("Cannot export with QR bill when creditor info is invalid")
    @MainActor
    func cannotExportWithQRBillInvalidCreditor() {
        let vm = InvoicesViewModel()
        vm.creditorInfo = .empty

        #expect(!vm.canExportWithQRBill)
    }
}
