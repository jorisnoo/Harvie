//
//  Strings+TemplateRendering.swift
//  Harvie
//

import Foundation

extension Strings.Errors {
    nonisolated static let contentBlockingUnavailable = String(
        localized: "This template can't be rendered because its remote content couldn't be blocked. Please try again."
    )
}
