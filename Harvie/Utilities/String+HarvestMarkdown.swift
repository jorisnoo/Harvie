//
//  String+HarvestMarkdown.swift
//  Harvie
//

import SwiftUI

extension String {
    /// Renders Harvest-flavored markdown as an `AttributedString`.
    /// Harvest treats both `*text*` and `**text**` as bold; `- item` as list bullets.
    var harvestMarkdown: AttributedString {
        // Normalize line endings, then convert list markers to bullet points
        let normalized = self
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let preprocessed = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.drop(while: { $0 == " " })
                if trimmed.hasPrefix("- ") {
                    return "• " + trimmed.dropFirst(2)
                }
                return String(line)
            }
            .joined(separator: "\n")

        var result = (try? AttributedString(
            markdown: preprocessed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(preprocessed)

        // Harvest: both *text* and **text** render as bold only (no italic)
        for run in result.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.stronglyEmphasized) || intent.contains(.emphasized) {
                result[run.range].font = Font.body.bold()
                result[run.range].inlinePresentationIntent = .stronglyEmphasized
            }
        }

        return result
    }
}
