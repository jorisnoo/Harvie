//
//  TemplateContentPolicy.swift
//  Harvie
//

import Foundation
import os.log
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "TemplateContentPolicy")

/// Keeps rendered templates — including imported, third-party ones — to local content:
/// no remote images, stylesheets, fonts or tracking pixels.
@MainActor
enum TemplateContentPolicy {
    /// Blocks every load, then exempts the schemes that never leave the machine (content
    /// blocker regexes don't support alternation, hence one rule per scheme). File reads
    /// are further confined by `loadFileURL(_:allowingReadAccessTo:)`.
    private static let rules = """
        [
            {"trigger": {"url-filter": ".*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": "^about:"}, "action": {"type": "ignore-previous-rules"}},
            {"trigger": {"url-filter": "^data:"}, "action": {"type": "ignore-previous-rules"}},
            {"trigger": {"url-filter": "^blob:"}, "action": {"type": "ignore-previous-rules"}},
            {"trigger": {"url-filter": "^file:"}, "action": {"type": "ignore-previous-rules"}}
        ]
        """

    private static var compiledRuleList: WKContentRuleList?

    /// The compiled blocking rules, or nil if WebKit couldn't compile them — callers
    /// must then fail closed for untrusted content.
    static func ruleList() async -> WKContentRuleList? {
        if let compiledRuleList { return compiledRuleList }
        do {
            let ruleList = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WKContentRuleList?, Error>) in
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "HarvieTemplateLocalContentOnly",
                    encodedContentRuleList: rules
                ) { ruleList, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ruleList)
                    }
                }
            }
            compiledRuleList = ruleList
            return ruleList
        } catch {
            logger.error("Failed to compile template content rules: \(error.localizedDescription)")
            return nil
        }
    }

    /// Whether `url` stays on this machine: inline documents and data, or a file inside
    /// `directory` (the template's own folder).
    nonisolated static func isLocal(_ url: URL?, within directory: URL?) -> Bool {
        guard let url, let scheme = url.scheme?.lowercased() else { return false }
        switch scheme {
        case "about", "data", "blob":
            return true
        case "file":
            guard let directory else { return false }
            let root = directory.standardizedFileURL.resolvingSymlinksInPath().path
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            return path == root || path.hasPrefix(root + "/")
        default:
            return false
        }
    }
}
