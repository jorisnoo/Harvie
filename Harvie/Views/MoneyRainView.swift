//
//  MoneyRainView.swift
//  Harvie
//

import AppKit
import os.log
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "MoneyRain")

// MARK: - Shared Trigger

@Observable
final class MoneyRainState {
    static let shared = MoneyRainState()
    var trigger = false
}

// MARK: - Overlay (always present, renders drops when triggered)

struct MoneyRainOverlay: View {
    private var rain = MoneyRainState.shared

    @State private var gifDrops: [GIFDrop] = []
    @State private var emojiDrops: [EmojiDrop] = []
    @State private var animate = false
    @State private var downloadTask: Task<[Data], Never>?

    // Vintage animated GIFs from GifCities (Internet Archive's GeoCities collection)
    private static let gifURLs: [URL] = [
        "https://blob.gifcities.org/gifcities/FD34DR5CQAHEL4A6WSBRABODHOICHW6O.gif",
        "https://blob.gifcities.org/gifcities/GZPU2HXMN3YJ53MDTFIR724IRQUXRRAS.gif",
        "https://blob.gifcities.org/gifcities/TCL5KDLMOYNSRCIP5S45TPF2DRVMM2A6.gif",
        "https://blob.gifcities.org/gifcities/MNAATEMQJV5SNFDVLWCTMVJH7RKPMNGP.gif",
        "https://blob.gifcities.org/gifcities/XJOBQLX6NQGXHGLGSOIYPVTMAHVYIMWU.gif",
        "https://blob.gifcities.org/gifcities/GDAKH6VTEUAWS2KAEGQ2RZVW46CQL6E7.gif",
        "https://blob.gifcities.org/gifcities/2Z5PYVJIF73SUHTGBSVDSEBSB45NBZXK.gif",
        "https://blob.gifcities.org/gifcities/LGTEKHASHYPCAGKZQVQQ7NPH5OSZJE6V.gif",
    ].compactMap { URL(string: $0) }

    private static let emojiSymbols = ["💵", "💰", "💲", "$", "🤑", "💸"]
    private static let maxDuration: Double = 4.5
    private static let maxDelay: Double = 2.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(gifDrops) { drop in
                    AnimatedGIFView(data: drop.gifData)
                        .frame(width: drop.size, height: drop.size)
                        .offset(
                            x: drop.xFraction * geo.size.width - geo.size.width / 2,
                            y: animate ? geo.size.height + 100 : -100
                        )
                        .rotationEffect(.degrees(animate ? drop.endRotation : 0))
                        .animation(
                            .easeIn(duration: drop.duration).delay(drop.delay),
                            value: animate
                        )
                }

                ForEach(emojiDrops) { drop in
                    Text(drop.symbol)
                        .font(.system(size: drop.size))
                        .offset(
                            x: drop.xFraction * geo.size.width - geo.size.width / 2,
                            y: animate ? geo.size.height + 80 : -80
                        )
                        .rotationEffect(.degrees(animate ? drop.endRotation : 0))
                        .animation(
                            .easeIn(duration: drop.duration).delay(drop.delay),
                            value: animate
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .onChange(of: rain.trigger) { _, triggered in
            if triggered {
                logger.info("💰 Rain triggered — starting")
                startRain()
            }
        }
    }

    private func startRain() {
        // Reset from any previous run
        animate = false
        gifDrops = []
        emojiDrops = []

        // Start with emojis immediately
        emojiDrops = (0..<80).map { _ in
            EmojiDrop(
                symbol: Self.emojiSymbols.randomElement()!,
                xFraction: Double.random(in: 0...1),
                size: CGFloat.random(in: 20...56),
                duration: Double.random(in: 2...Self.maxDuration),
                delay: Double.random(in: 0...Self.maxDelay),
                endRotation: Double.random(in: -540...540)
            )
        }
        logger.info("💰 Created \(emojiDrops.count) emoji drops — animating")

        // Trigger animation on next frame so SwiftUI sees the position change
        DispatchQueue.main.async {
            animate = true
        }

        // Try to swap in GIFs if available
        if let task = downloadTask {
            Task {
                let gifData = await task.value
                if !gifData.isEmpty {
                    emojiDrops = []
                    gifDrops = (0..<50).map { _ in
                        GIFDrop(
                            gifData: gifData.randomElement()!,
                            xFraction: Double.random(in: 0...1),
                            size: CGFloat.random(in: 40...90),
                            duration: Double.random(in: 2...Self.maxDuration),
                            delay: Double.random(in: 0...Self.maxDelay),
                            endRotation: Double.random(in: -180...180)
                        )
                    }
                    animate = false
                    DispatchQueue.main.async { animate = true }
                    logger.info("💰 Swapped to \(gifDrops.count) GIF drops")
                }
            }
        }

        // Auto-dismiss
        let totalTime = Self.maxDuration + Self.maxDelay + 0.5
        Task {
            try? await Task.sleep(for: .seconds(totalTime))
            gifDrops = []
            emojiDrops = []
            animate = false
            rain.trigger = false
            logger.info("💰 Rain finished")
        }
    }

    // Pre-download GIFs in the background so they're ready when triggered
    static func preload() {
        MoneyRainState.shared // ensure initialized
        Task {
            let gifData = await downloadGIFs()
            logger.info("💰 Preloaded \(gifData.count) GIFs")
            _preloadedGIFs = gifData
        }
    }

    private static var _preloadedGIFs: [Data] = []

    private static func downloadGIFs() async -> [Data] {
        await withTaskGroup(of: Data?.self) { group in
            for url in gifURLs {
                group.addTask {
                    try? await URLSession.shared.data(from: url).0
                }
            }
            var results: [Data] = []
            for await data in group {
                if let data { results.append(data) }
            }
            return results
        }
    }
}

// MARK: - Drop Models

private struct GIFDrop: Identifiable {
    let id = UUID()
    let gifData: Data
    let xFraction: Double
    let size: CGFloat
    let duration: Double
    let delay: Double
    let endRotation: Double
}

private struct EmojiDrop: Identifiable {
    let id = UUID()
    let symbol: String
    let xFraction: Double
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
