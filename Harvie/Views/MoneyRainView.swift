//
//  MoneyRainView.swift
//  Harvie
//

import AppKit
import SwiftUI

// MARK: - Shared Trigger

@Observable
final class MoneyRainState {
    static let shared = MoneyRainState()
    var trigger = false
}

// MARK: - Overlay (watches trigger, spawns fullscreen window)

struct MoneyRainOverlay: View {
    private var rain = MoneyRainState.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: rain.trigger) { _, triggered in
                if triggered {
                    MoneyRainWindowController.shared.show()
                }
            }
    }
}

// MARK: - Fullscreen Window Controller

@MainActor
private final class MoneyRainWindowController {
    static let shared = MoneyRainWindowController()

    private var window: NSWindow?

    static let gifData: [Data] = {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: resourceURL,
            includingPropertiesForKeys: nil
        ) else { return [] }
        let gifs = files
            .filter { $0.pathExtension.lowercased() == "gif" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? Data(contentsOf: $0) }
        return gifs
    }()

    func show() {
        guard window == nil, !Self.gifData.isEmpty else {
            if Self.gifData.isEmpty { MoneyRainState.shared.trigger = false }
            return
        }

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let win = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let rainView = MoneyRainContentView(gifData: Self.gifData) { [weak self] in
            self?.dismiss()
        }
        win.contentView = NSHostingView(rootView: rainView)

        window = win
        win.orderFrontRegardless()
    }

    private func dismiss() {
        window?.orderOut(nil)
        window = nil
        MoneyRainState.shared.trigger = false
    }
}

// MARK: - Rain Content View

private struct MoneyRainContentView: View {
    let gifData: [Data]
    let onFinished: () -> Void

    @State private var drops: [GIFDrop] = []
    @State private var falling = false
    @State private var visible = false
    @State private var fadeOut = false

    private static let fallDuration: Double = 8
    private static let maxDelay: Double = 2.5
    private static let lingerTime: Double = 3

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(drops) { drop in
                    AnimatedGIFView(data: drop.gifData)
                        .frame(width: drop.size, height: drop.size)
                        .offset(
                            x: drop.xFraction * geo.size.width - geo.size.width / 2,
                            y: falling
                                ? geo.size.height + 100
                                : -drop.startYOffset
                        )
                        .rotationEffect(.degrees(falling ? drop.endRotation : 0))
                        .opacity(fadeOut ? 0 : (visible ? 1 : 0))
                        .animation(
                            .easeIn(duration: drop.duration).delay(drop.delay),
                            value: falling
                        )
                        .animation(
                            .easeIn(duration: 0.3).delay(drop.delay),
                            value: visible
                        )
                        .animation(
                            .easeOut(duration: 1.5),
                            value: fadeOut
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startRain()
        }
    }

    private func startRain() {
        drops = (0..<60).map { _ in
            GIFDrop(
                gifData: gifData.randomElement()!,
                xFraction: Double.random(in: 0...1),
                startYOffset: CGFloat.random(in: 50...300),
                size: CGFloat.random(in: 50...120),
                duration: Double.random(in: 4...Self.fallDuration),
                delay: Double.random(in: 0...Self.maxDelay),
                endRotation: Double.random(in: -180...180)
            )
        }

        visible = true
        falling = true

        // Fade out after fall + linger
        let fadeStart = Self.fallDuration + Self.maxDelay + Self.lingerTime
        Task {
            try? await Task.sleep(for: .seconds(fadeStart))
            fadeOut = true
            try? await Task.sleep(for: .seconds(2))
            onFinished()
        }
    }
}

// MARK: - Drop Model

private struct GIFDrop: Identifiable {
    let id = UUID()
    let gifData: Data
    let xFraction: Double
    let startYOffset: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double
    let endRotation: Double
}

// MARK: - Animated GIF

private struct AnimatedGIFView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.canDrawSubviewsIntoLayer = true
        if let image = NSImage(data: data) {
            imageView.image = image
        }
        return imageView
    }

    func updateNSView(_: NSImageView, context: Context) {}
}
