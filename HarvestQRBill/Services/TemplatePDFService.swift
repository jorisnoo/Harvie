//
//  TemplatePDFService.swift
//  HarvestQRBill
//

import Foundation
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

    func renderPDF(html: String, css: String) async throws -> PDFDocument {
        let fullHTML = buildHTMLDocument(html: html, css: css)
        return try await renderHTMLToPDF(fullHTML)
    }

    func renderTemplate(
        template: InvoiceTemplate,
        context: [String: Any]
    ) async throws -> PDFDocument {
        let processedHTML = TemplateEngine.render(template.htmlContent, with: context)
        return try await renderPDF(html: processedHTML, css: template.cssContent)
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
        html, body {
            width: 210mm;
            min-height: 297mm;
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
        }
        @media print {
            html, body {
                width: 210mm;
                min-height: 297mm;
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
        let webView = WKWebView(frame: CGRect(
            x: 0, y: 0,
            width: Self.a4Width,
            height: Self.a4Height
        ))
        webView.setValue(false, forKey: "drawsBackground")

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PDFNavigationDelegate { result in
                switch result {
                case .success(let document):
                    continuation.resume(returning: document)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Keep delegate alive
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.navigationDelegate = delegate

            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}

private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    enum PDFError: Error, LocalizedError {
        case renderingFailed
        case timeout

        var errorDescription: String? {
            switch self {
            case .renderingFailed:
                return "Failed to render the template to PDF."
            case .timeout:
                return "PDF rendering timed out."
            }
        }
    }

    private let completion: (Result<PDFDocument, Error>) -> Void
    private var hasCompleted = false

    init(completion: @escaping (Result<PDFDocument, Error>) -> Void) {
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

    private func createPDF(from webView: WKWebView) {
        guard !hasCompleted else { return }

        let config = WKPDFConfiguration()
        // A4 in points
        config.rect = CGRect(
            x: 0, y: 0,
            width: TemplatePDFService.a4Width,
            height: TemplatePDFService.a4Height
        )

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
