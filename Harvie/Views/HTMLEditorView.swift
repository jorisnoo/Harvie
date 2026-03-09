//
//  HTMLEditorView.swift
//  Harvie
//

import AppKit
import SwiftUI

struct HTMLEditorView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var onChange: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.usesFindPanel = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator

        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(to: textView)

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        textView.isEditable = isEditable

        if textView.string != text {
            let visibleRect = scrollView.documentVisibleRect
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.applyHighlighting(to: textView)
            textView.selectedRanges = selectedRanges
            scrollView.documentView?.scroll(visibleRect.origin)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onChange: onChange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onChange: () -> Void
        weak var textView: NSTextView?
        private var isUpdating = false

        private static let highlightRules: [(NSRegularExpression, NSColor)] = [
            (try! NSRegularExpression(pattern: "<[^>]+>"), .systemBlue),
            (try! NSRegularExpression(pattern: "\\{\\{[^}]+\\}\\}"), .systemOrange),
            (try! NSRegularExpression(pattern: "[a-z-]+\\s*:"), .systemTeal),
            (try! NSRegularExpression(pattern: "\"[^\"]*\""), .systemGreen),
            (try! NSRegularExpression(pattern: "<!--[\\s\\S]*?-->"), .systemGray),
            (try! NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/"), .systemGray),
        ]

        init(text: Binding<String>, onChange: @escaping () -> Void) {
            self._text = text
            self.onChange = onChange
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertVariable(_:)),
                name: .insertTemplateVariable,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func handleInsertVariable(_ notification: Notification) {
            guard let token = notification.object as? String,
                  let textView, textView.window?.firstResponder === textView else { return }
            textView.insertText(token, replacementRange: textView.selectedRange())
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }

            isUpdating = true
            text = textView.string
            applyHighlighting(to: textView)
            onChange()
            isUpdating = false
        }

        func applyHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            textStorage.beginEditing()

            let fullRange = NSRange(location: 0, length: textStorage.length)
            let string = textStorage.string

            // Reset to default
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)

            let nsRange = NSRange(location: 0, length: (string as NSString).length)
            for (regex, color) in Self.highlightRules {
                for match in regex.matches(in: string, range: nsRange) {
                    textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                }
            }

            textStorage.endEditing()
        }
    }
}
