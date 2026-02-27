//
//  TemplatePDFService.swift
//  HarvestQRBill
//

import AppKit
import Foundation
import ObjectiveC
import PDFKit
import WebKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HarvestQRBill", category: "TemplatePDF")

@MainActor
final class TemplatePDFService {
    static let shared = TemplatePDFService()

    // A4 dimensions in points (72 dpi): 595.28 x 841.89
    static let a4Width: CGFloat = 595.28
    static let a4Height: CGFloat = 841.89

    /// Hidden window that provides the window-server context WKWebView needs.
    /// Positioned on-screen with near-zero alpha so the window server allocates GPU resources.
    private lazy var renderWindow: NSWindow = {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: Self.a4Width, height: Self.a4Height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0.01
        window.collectionBehavior = [.ignoresCycle, .stationary]
        window.orderBack(nil)
        return window
    }()

    func renderPDF(html: String, css: String) async throws -> PDFDocument {
        let fullHTML = buildHTMLDocument(html: html, css: css)
        return try await renderHTMLToPDF(fullHTML)
    }

    func renderTemplate(
        template: InvoiceTemplate,
        context: [String: Any]
    ) async throws -> PDFDocument {
        let processedHTML = TemplateEngine.render(template.resolvedHTMLContent(), with: context)
        let css = template.resolvedCSSContent() + "\n" + template.columnVisibility.cssVariables()
        return try await renderPDF(html: processedHTML, css: css)
    }

    private func buildHTMLDocument(html: String, css: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        @page {
            size: A4;
            margin: 0;
        }
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        html {
            zoom: 0.75;
        }
        html, body {
            width: 210mm;
            min-height: 297mm;
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
        }
        @media print {
            html {
                zoom: 0.75;
            }
            html, body {
                width: 210mm;
                min-height: 297mm;
                orphans: 3;
                widows: 3;
            }
        }
        \(css)
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }

    private func renderHTMLToPDF(_ html: String) async throws -> PDFDocument {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.suppressesIncrementalRendering = true

        // Templates are pure HTML/CSS (Mustache processed server-side) — disable
        // features we don't need to reduce WebContent sandbox probe warnings.
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = webpagePrefs

        config.preferences.isElementFullscreenEnabled = false
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: Self.a4Width, height: Self.a4Height),
            configuration: config
        )
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        renderWindow.contentView = webView

        defer { renderWindow.contentView = nil }

        return try await withThrowingTaskGroup(of: PDFDocument.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { continuation in
                    let delegate = PDFNavigationDelegate(webView: webView) { result in
                        switch result {
                        case .success(let document):
                            continuation.resume(returning: document)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }

                    // Retain delegate via associated object — WKWebView.navigationDelegate is weak
                    objc_setAssociatedObject(webView, "navDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
                    webView.navigationDelegate = delegate
                    webView.loadHTMLString(html, baseURL: nil)
                }
            }

            group.addTask { @MainActor in
                try await Task.sleep(for: .seconds(10))
                throw PDFNavigationDelegate.PDFError.timeout
            }

            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    enum PDFError: Error, LocalizedError {
        case renderingFailed
        case processTerminated
        case timeout

        var errorDescription: String? {
            switch self {
            case .renderingFailed:
                return "Failed to render the template to PDF."
            case .processTerminated:
                return "The web rendering process terminated unexpectedly."
            case .timeout:
                return "PDF rendering timed out."
            }
        }
    }

    private let webView: WKWebView
    private let completion: (Result<PDFDocument, Error>) -> Void
    private var hasCompleted = false

    init(webView: WKWebView, completion: @escaping (Result<PDFDocument, Error>) -> Void) {
        self.webView = webView
        self.completion = completion
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        // Small delay to let the page finish layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.createPDF(from: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        logger.error("Provisional navigation failed: \(error.localizedDescription)")
        completion(.failure(error))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !hasCompleted else { return }
        hasCompleted = true
        logger.error("WebContent process terminated")
        completion(.failure(PDFError.processTerminated))
    }

    private func createPDF(from webView: WKWebView) {
        guard !hasCompleted else { return }

        let config = WKPDFConfiguration()
        // Leave config.rect at default (.null) so WKWebView paginates
        // content across multiple A4 pages automatically via @page rules.

        webView.createPDF(configuration: config) { [weak self] result in
            guard let self, !self.hasCompleted else { return }
            self.hasCompleted = true

            switch result {
            case .success(let data):
                if let document = PDFDocument(data: data) {
                    self.completion(.success(document))
                } else {
                    self.completion(.failure(PDFError.renderingFailed))
                }
            case .failure(let error):
                self.completion(.failure(error))
            }
        }
    }
}
