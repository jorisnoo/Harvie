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
    var baseURL: URL? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.isElementFullscreenEnabled = false

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

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String?
        var lastBaseURL: URL?
        private var tempFileURL: URL?

        func load(html: String, baseURL: URL?, in webView: WKWebView) {
            lastLoadedHTML = html
            lastBaseURL = baseURL
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
