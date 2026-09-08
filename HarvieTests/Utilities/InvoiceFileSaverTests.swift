import Foundation
import Testing
@testable import Harvie

@Suite("PDF filenames")
@MainActor
struct InvoiceFileSaverTests {
    @Test func preservesExistingFilesAndContainsPaths() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = InvoiceFileSaver.availableURL(fileName: "client.pdf", in: folder)
        try Data("first".utf8).write(to: first)
        let second = InvoiceFileSaver.availableURL(fileName: "client.pdf", in: folder)
        #expect(second.lastPathComponent == "client_1.pdf")
        #expect(try String(contentsOf: first, encoding: .utf8) == "first")
        let unsafe = InvoiceFileSaver.availableURL(fileName: "../other/invoice.pdf", in: folder)
        #expect(unsafe.deletingLastPathComponent().path == folder.path)
        #expect(!InvoiceFileSaver.isValidPath(URL(fileURLWithPath: folder.path + "-other/a.pdf"), within: folder))
    }
}
