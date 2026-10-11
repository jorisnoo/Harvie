//
//  TemplatePreviewView.swift
//  Harvie
//

import OSLog
import SwiftUI
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "TemplatePreview")

struct TemplatePreviewView: NSViewRepresentable {
    let html: String
    var baseURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.isElementFullscreenEnabled = false

        // Same restrictions as PDF rendering: no scripts, no network.
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = webpagePrefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.load(html: html, baseURL: baseURL, in: webView)
        return webView
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.stopLoading()
        coordinator.cleanupTempFile()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard html != context.coordinator.lastLoadedHTML else { return }
        context.coordinator.load(html: html, baseURL: baseURL, in: webView)
    }

    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?
        var lastBaseURL: URL?
        private var tempFileURL: URL?
        private var loadTask: Task<Void, Never>?
        private var hasContentRules = false

        func load(html: String, baseURL: URL?, in webView: WKWebView) {
            lastLoadedHTML = html
            lastBaseURL = baseURL
            loadTask?.cancel()
            loadTask = Task { [weak self, weak webView] in
                guard let self, let webView, await self.installContentRules(in: webView),
                      !Task.isCancelled else { return }
                self.show(html: html, baseURL: baseURL, in: webView)
            }
        }

        /// Templates may be imported from anywhere, so the preview only renders once
        /// remote loads are blocked (fails closed if the rules can't be compiled).
        private func installContentRules(in webView: WKWebView) async -> Bool {
            if hasContentRules { return true }
            guard let ruleList = await TemplateContentPolicy.ruleList() else {
                logger.error("Template preview disabled: content blocking unavailable")
                return false
            }
            webView.configuration.userContentController.add(ruleList)
            hasContentRules = true
            return true
        }

        private func show(html: String, baseURL: URL?, in webView: WKWebView) {
            cleanupTempFile()

            if let baseURL {
                let fileURL = baseURL.appendingPathComponent(".harvie-preview.html")
                try? html.write(to: fileURL, atomically: true, encoding: .utf8)
                tempFileURL = fileURL
                webView.loadFileURL(fileURL, allowingReadAccessTo: baseURL)
            } else {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func cleanupTempFile() {
            if let url = tempFileURL {
                try? FileManager.default.removeItem(at: url)
                tempFileURL = nil
            }
        }

        /// Only local content may load; links in the preview never navigate.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let isLocal = TemplateContentPolicy.isLocal(navigationAction.request.url, within: lastBaseURL)
            let allowed = isLocal && navigationAction.navigationType != .linkActivated && navigationAction.targetFrame != nil
            decisionHandler(allowed ? .allow : .cancel)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            logger.warning("WebContent process terminated — reloading preview")
            if let html = lastLoadedHTML {
                load(html: html, baseURL: lastBaseURL, in: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logger.error("Navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            logger.error("Provisional navigation failed: \(error.localizedDescription)")
        }
    }
}
