//
//  TemplateFileManager.swift
//  HarvestQRBill
//

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "TemplateFileManager")

enum TemplateFileManager {
    private static var templatesRoot: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("HarvestQRBill/Templates")
    }

    /// Builds the canonical folder name: `<sanitized-name>-<uuid>`
    static func templateDirectory(for id: UUID, name: String) -> URL {
        let folderName = "\(sanitize(name))-\(id.uuidString)"
        return templatesRoot.appendingPathComponent(folderName)
    }

    /// Finds existing directory by UUID suffix, regardless of name.
    static func existingDirectory(for id: UUID) -> URL? {
        let fm = FileManager.default
        let root = templatesRoot
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return nil
        }
        let suffix = id.uuidString
        return entries.first { $0.lastPathComponent.hasSuffix(suffix) }
    }

    static func htmlURL(for id: UUID) -> URL? {
        existingDirectory(for: id)?.appendingPathComponent("template.html")
    }

    static func cssURL(for id: UUID) -> URL? {
        existingDirectory(for: id)?.appendingPathComponent("styles.css")
    }

    static func loadHTML(for id: UUID) -> String? {
        guard let url = htmlURL(for: id) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func loadCSS(for id: UUID) -> String? {
        guard let url = cssURL(for: id) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func save(html: String, css: String, for id: UUID, name: String) {
        let target = templateDirectory(for: id, name: name)

        // Rename existing folder if the name changed
        if let existing = existingDirectory(for: id), existing != target {
            try? FileManager.default.moveItem(at: existing, to: target)
        }

        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try html.write(to: target.appendingPathComponent("template.html"), atomically: true, encoding: .utf8)
            try css.write(to: target.appendingPathComponent("styles.css"), atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to save template files for \(id): \(error.localizedDescription)")
        }
    }

    static func delete(for id: UUID) {
        guard let dir = existingDirectory(for: id) else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    static func filesExist(for id: UUID) -> Bool {
        existingDirectory(for: id) != nil
    }

    static func revealInFinder(for id: UUID) {
        guard let dir = existingDirectory(for: id) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([dir])
    }

    static func openInEditor(for id: UUID) {
        guard let dir = existingDirectory(for: id) else { return }
        NSWorkspace.shared.open(dir)
    }

    static func revealTemplatesFolder() {
        let dir = templatesRoot
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = name.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(cleaned))
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        return result.isEmpty ? "template" : result
    }
}
