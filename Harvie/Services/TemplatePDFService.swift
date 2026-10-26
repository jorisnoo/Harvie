//
//  TemplatePDFService.swift
//  Harvie
//

import AppKit
import Foundation
import ObjectiveC
import PDFKit
import WebKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "TemplatePDF")

/// What a render produces from the laid-out page.
private enum RenderOutput {
    /// A single page capturing `rect` of the document.
    case singlePage(CGRect)
    /// The whole document, paginated onto A4 pages.
    case a4Pages
}

@MainActor
final class TemplatePDFService {
    static let shared = TemplatePDFService()

    // A4 dimensions in points (72 dpi): 595.28 x 841.89
    static let a4Width: CGFloat = 595.28
    static let a4Height: CGFloat = 841.89
    /// Space above and below content on printed pages (above only after the first page).
    static let pageMarginMM = 12
    static let pageMargin = CGFloat(pageMarginMM) * 72 / 25.4

    /// Hidden window that provides the window-server context WKWebView needs. It sits
    /// just past the bottom-left corner of the main display — one point stays on screen,
    /// so the window keeps a screen to render for — at near-zero alpha, and lets every
    /// click pass through.
    private lazy var renderWindow: NSWindow = {
        let window = NSWindow(
            contentRect: CGRect(x: 1 - Self.a4Width, y: 1 - Self.a4Height, width: Self.a4Width, height: Self.a4Height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.ignoresCycle, .stationary]
        window.orderBack(nil)
        return window
    }()

    /// Renders `html` paginated onto A4 pages. Untrusted content (anything but the
    /// app's own templates) is refused if remote loads can't be blocked.
    func renderPDF(html: String, css: String, baseURL: URL? = nil, isTrusted: Bool = false) async throws -> PDFDocument {
        let fullHTML = buildHTMLDocument(html: html, css: css)
        return try await renderHTMLToPDF(fullHTML, baseURL: baseURL, output: .a4Pages, isTrusted: isTrusted)
    }

    func renderWatermarkPage(text: String, dateText: String?, css: String) async throws -> PDFPage {
        var dateDiv = ""
        if let dateText {
            dateDiv = "<div class=\"date\">\(dateText)</div>"
        }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
        @page { size: A4; margin: 0; }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html { zoom: 0.75; }
        html, body { width: 210mm; height: 297mm; position: relative; overflow: hidden; }
        \(css)
        </style>
        </head>
        <body>
        <div class="watermark">
            <div class="text">\(text)</div>
            \(dateDiv)
        </div>
        </body>
        </html>
        """

        let a4Rect = CGRect(origin: .zero, size: CGSize(width: Self.a4Width, height: Self.a4Height))
        let document = try await renderHTMLToPDF(html, output: .singlePage(a4Rect), isTrusted: true)
        guard let page = document.page(at: 0) else {
            throw PDFNavigationDelegate.PDFError.renderingFailed
        }
        return page
    }

    func renderTemplate(
        template: InvoiceTemplate,
        context: [String: Any],
        columnVisibility: ColumnVisibility = .default
    ) async throws -> PDFDocument {
        let processedHTML = TemplateEngine.render(template.resolvedHTMLContent(), with: context)
        let css = template.resolvedCSSContent() + "\n" + columnVisibility.cssVariables()
        let baseURL = template.isBuiltIn ? nil : TemplateFileManager.existingDirectory(for: template.id)
        return try await renderPDF(html: processedHTML, css: css, baseURL: baseURL, isTrusted: template.isBuiltIn)
    }

    private func buildHTMLDocument(html: String, css: String) -> String {
        // On screen (single-page captures and the sliced fallback), the 0.75 zoom maps CSS
        // pixels to PDF points so 210mm spans an A4 page. Printing maps CSS millimetres to
        // paper millimetres by itself and paginates, so it needs neither the zoom nor the
        // one-page minimum height (which would otherwise spill onto a blank extra page).
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        @page {
            size: A4;
            margin: \(Self.pageMarginMM)mm 0;
        }
        /* The template's own padding frames the first page; later pages need a margin
           so content doesn't run to the paper edge after a page break. */
        @page :first {
            margin-top: 0;
        }
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
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
                zoom: 1;
            }
            html, body {
                width: 210mm;
                min-height: 0;
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

    /// Renders run strictly one at a time: they share the single render window and,
    /// per template, a fixed temp-file path, so overlapping renders would detach each
    /// other's web view mid-render and clobber each other's temp file.
    private var pendingRender: Task<PDFDocument, Error>?

    private func renderHTMLToPDF(
        _ html: String,
        baseURL: URL? = nil,
        output: RenderOutput,
        isTrusted: Bool
    ) async throws -> PDFDocument {
        let previous = pendingRender
        let render = Task {
            _ = try? await previous?.value
            return try await performRender(html, baseURL: baseURL, output: output, isTrusted: isTrusted)
        }
        pendingRender = render
        return try await render.value
    }

    private func performRender(
        _ html: String,
        baseURL: URL?,
        output: RenderOutput,
        isTrusted: Bool
    ) async throws -> PDFDocument {
        // Templates must never reach the network. If the blocker can't be compiled, only
        // the app's own content renders (navigation is still restricted for it below).
        let ruleList = await TemplateContentPolicy.ruleList()
        guard ruleList != nil || isTrusted else {
            throw PDFNavigationDelegate.PDFError.contentBlockingUnavailable
        }

        // When a baseURL is provided, write HTML to a temp file and use loadFileURL
        // so WKWebView's WebContent process can access local resources (images, etc.)
        var tempFileURL: URL?
        if let baseURL {
            let fileURL = baseURL.appendingPathComponent(".harvie-render.html")
            try? html.write(to: fileURL, atomically: true, encoding: .utf8)
            tempFileURL = fileURL
        }
        defer { if let url = tempFileURL { try? FileManager.default.removeItem(at: url) } }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.suppressesIncrementalRendering = true
        if let ruleList {
            config.userContentController.add(ruleList)
        }

        // Templates are pure HTML/CSS (Mustache processed server-side) — disable
        // features we don't need to reduce WebContent sandbox probe warnings.
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = webpagePrefs

        config.preferences.isElementFullscreenEnabled = false
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.shouldPrintBackgrounds = true

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

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PDFNavigationDelegate(webView: webView, output: output, readAccessDirectory: baseURL) { result in
                continuation.resume(with: result)
            }

            // Retain delegate via associated object — WKWebView.navigationDelegate is weak
            objc_setAssociatedObject(webView, "navDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.navigationDelegate = delegate
            delegate.startTimeout(seconds: 20)

            if let tempFileURL, let baseURL {
                // Read access is limited to the template's own folder.
                webView.loadFileURL(tempFileURL, allowingReadAccessTo: baseURL)
            } else {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}

@MainActor
private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    enum PDFError: Error, LocalizedError {
        case renderingFailed
        case processTerminated
        case timeout
        case contentBlockingUnavailable

        var errorDescription: String? {
            switch self {
            case .renderingFailed:
                return Strings.Errors.renderingFailed
            case .processTerminated:
                return Strings.Errors.processTerminated
            case .timeout:
                return Strings.Errors.renderingTimeout
            case .contentBlockingUnavailable:
                return Strings.Errors.contentBlockingUnavailable
            }
        }
    }

    // weak: the web view retains this delegate via an associated object, so a
    // strong reference back would create a retain cycle and leak both per render.
    private weak var webView: WKWebView?
    private let output: RenderOutput
    /// The only folder file URLs may point into (the template's own directory).
    private let readAccessDirectory: URL?
    private let completion: (Result<PDFDocument, Error>) -> Void
    private var hasCompleted = false
    private var hasAllowedDocumentLoad = false
    private var printContinuation: CheckedContinuation<Bool, Never>?

    init(
        webView: WKWebView,
        output: RenderOutput,
        readAccessDirectory: URL?,
        completion: @escaping (Result<PDFDocument, Error>) -> Void
    ) {
        self.webView = webView
        self.output = output
        self.readAccessDirectory = readAccessDirectory
        self.completion = completion
        super.init()
    }

    /// The continuation driving the render is resumed only through `finish`, so the
    /// timeout covers loading, printing and the fallback alike.
    func startTimeout(seconds: Int) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !self.hasCompleted else { return }
            self.webView?.stopLoading()
            logger.error("PDF render timed out after \(seconds)s")
            self.finish(.failure(PDFError.timeout))
            self.resumePrint(succeeded: false)
        }
    }

    private func finish(_ result: Result<PDFDocument, Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(result)
    }

    // MARK: - Navigation

    /// Allows the initial document load and local subframes only; a template can't
    /// navigate anywhere else (remote subresources are blocked by the content rules).
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let isLocal = TemplateContentPolicy.isLocal(navigationAction.request.url, within: readAccessDirectory)
        guard let targetFrame = navigationAction.targetFrame else {
            decisionHandler(.cancel)
            return
        }
        if targetFrame.isMainFrame {
            let isInitialLoad = !hasAllowedDocumentLoad
            hasAllowedDocumentLoad = true
            decisionHandler(isLocal && isInitialLoad ? .allow : .cancel)
        } else {
            decisionHandler(isLocal ? .allow : .cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        Task { [weak self] in
            // Small delay to let the page finish layout
            try? await Task.sleep(for: .milliseconds(100))
            await self?.produceOutput()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !hasCompleted else { return }
        logger.error("Provisional navigation failed: \(error.localizedDescription)")
        finish(.failure(error))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !hasCompleted else { return }
        logger.error("WebContent process terminated")
        finish(.failure(PDFError.processTerminated))
    }

    // MARK: - Output

    private func produceOutput() async {
        guard !hasCompleted, let webView else { return }
        do {
            let document: PDFDocument
            switch output {
            case .singlePage(let rect):
                document = try await Self.capture(webView, rect: rect)
            case .a4Pages:
                document = try await a4Document(from: webView)
            }
            finish(.success(document))
        } catch {
            finish(.failure(error))
        }
    }

    /// Prints through WebKit's own pagination, which honours `@page` and page-break CSS.
    /// If printing yields nothing usable, the continuous rendering is sliced into A4 pages.
    private func a4Document(from webView: WKWebView) async throws -> PDFDocument {
        if let printed = await printA4(webView), Self.isUsableA4Document(printed) {
            return MarginFilledPDFPage.fillingMargins(of: printed, margin: TemplatePDFService.pageMargin)
        }
        guard !hasCompleted else { throw PDFError.timeout }
        logger.error("Printing the template produced no usable pages; slicing the screen rendering instead")
        return try await Self.sliceIntoA4Pages(webView)
    }

    private func printA4(_ webView: WKWebView) async -> PDFDocument? {
        guard let window = webView.window else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("harvie-print-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        let printInfo = NSPrintInfo(dictionary: [.jobSavingURL: url])
        printInfo.jobDisposition = .save
        printInfo.paperSize = NSSize(width: TemplatePDFService.a4Width, height: TemplatePDFService.a4Height)
        printInfo.orientation = .portrait
        // Margins come from the document's `@page` rules and the template's own padding.
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        // WebKit's printing view comes out blank without an explicit frame.
        operation.view?.frame = webView.bounds

        // A print that never reports back falls through to the sliced fallback.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            self?.resumePrint(succeeded: false)
        }

        // `run()` would block the main thread WebKit needs to deliver the pages; the
        // window-modal variant shows nothing with both panels off and reports back here.
        let succeeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            printContinuation = continuation
            operation.runModal(
                for: window,
                delegate: self,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }
        guard succeeded, let data = try? Data(contentsOf: url) else { return nil }
        return PDFDocument(data: data)
    }

    @objc private func printOperationDidRun(
        _ printOperation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        resumePrint(succeeded: success)
    }

    private func resumePrint(succeeded: Bool) {
        printContinuation?.resume(returning: succeeded)
        printContinuation = nil
    }

    /// WebKit occasionally prints blank pages; a real invoice always has text.
    private static func isUsableA4Document(_ document: PDFDocument) -> Bool {
        guard document.pageCount > 0,
              !(document.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return (0..<document.pageCount).allSatisfy { index in
            guard let size = document.page(at: index)?.bounds(for: .mediaBox).size else { return false }
            return abs(size.width - TemplatePDFService.a4Width) < 1 && abs(size.height - TemplatePDFService.a4Height) < 1
        }
    }

    /// Fallback pagination: cuts the continuous on-screen rendering into A4-high slices.
    /// Page-break CSS isn't honoured here, but every page is a true A4 page.
    private static func sliceIntoA4Pages(_ webView: WKWebView) async throws -> PDFDocument {
        let pageSize = CGSize(width: TemplatePDFService.a4Width, height: TemplatePDFService.a4Height)

        // A capture without a rect covers the whole document, which gives its height.
        guard let height = try await capture(webView, rect: nil).page(at: 0)?.bounds(for: .mediaBox).height else {
            throw PDFError.renderingFailed
        }
        // Allow for rounding, so a document exactly one page tall doesn't spill a sliver
        // onto a second page.
        let pageCount = max(1, Int(((height - 1) / pageSize.height).rounded(.up)))

        let document = PDFDocument()
        for index in 0..<pageCount {
            let rect = CGRect(origin: CGPoint(x: 0, y: CGFloat(index) * pageSize.height), size: pageSize)
            guard let page = try await capture(webView, rect: rect).page(at: 0) else {
                throw PDFError.renderingFailed
            }
            document.insert(page, at: document.pageCount)
        }
        return document
    }

    private static func capture(_ webView: WKWebView, rect: CGRect?) async throws -> PDFDocument {
        let configuration = WKPDFConfiguration()
        if let rect {
            configuration.rect = rect
        }
        let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            webView.createPDF(configuration: configuration) { result in
                continuation.resume(with: result)
            }
        }
        guard let document = PDFDocument(data: data) else {
            throw PDFError.renderingFailed
        }
        return document
    }
}
