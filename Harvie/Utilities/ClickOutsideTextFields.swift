//
//  ClickOutsideTextFields.swift
//  Harvie
//

import AppKit
import SwiftUI

private struct ClickOutsideTextFieldsModifier: ViewModifier {
    let action: () -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                    // If a text view is already the first responder, check whether
                    // the click lands inside it — if so, leave editing alone.
                    if let responder = event.window?.firstResponder as? NSView,
                       responder is NSTextView || responder is NSTextField {
                        let loc = responder.convert(event.locationInWindow, from: nil)
                        if responder.bounds.contains(loc) {
                            return event
                        }
                    }

                    guard let contentView = event.window?.contentView else { return event }
                    let location = contentView.convert(event.locationInWindow, from: nil)
                    let hitView = contentView.hitTest(location)
                    if !(hitView is NSTextField || hitView is NSTextView) {
                        action()
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

extension View {
    func onClickOutsideTextFields(perform action: @escaping () -> Void) -> some View {
        modifier(ClickOutsideTextFieldsModifier(action: action))
    }
}
