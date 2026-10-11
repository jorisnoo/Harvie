//
//  LinkPointerStyle.swift
//  Harvie
//

import AppKit
import SwiftUI

extension View {
    /// Shows the pointing-hand cursor while hovering, if enabled.
    func linkPointerStyle(isEnabled: Bool = true) -> some View {
        modifier(LinkPointerStyleModifier(isEnabled: isEnabled))
    }
}

private struct LinkPointerStyleModifier: ViewModifier {
    let isEnabled: Bool

    /// Whether this view pushed the cursor (macOS 14 fallback), so it is popped exactly once.
    @State private var didPushCursor = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(isEnabled ? PointerStyle.link : nil)
        } else {
            content
                .onHover { setCursorPushed($0 && isEnabled) }
                .onChange(of: isEnabled) { _, enabled in
                    if !enabled { setCursorPushed(false) }
                }
                .onDisappear { setCursorPushed(false) }
        }
    }

    private func setCursorPushed(_ pushed: Bool) {
        guard pushed != didPushCursor else { return }
        if pushed { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        didPushCursor = pushed
    }
}
