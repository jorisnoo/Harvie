//
//  MoneyRainView.swift
//  Harvie
//

import AppKit
import SwiftUI

struct MoneyRainView: View {
    var onFinished: (() -> Void)?

    @State private var gifDrops: [GIFDrop] = []
    @State private var emojiDrops: [EmojiDrop] = []
    @State private var animate = false

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
    private static let dropCount = 40
    private static let maxDuration: Double = 4.5
    private static let maxDelay: Double = 2.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // GIF-based drops (preferred)
                ForEach(gifDrops) { drop in
                    AnimatedGIFView(data: drop.gifData)
                        .frame(width: drop.size, height: drop.size)
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

                // Emoji fallback drops (when GIFs can't be fetched)
                ForEach(emojiDrops) { drop in
                    Text(drop.symbol)
                        .font(.system(size: drop.size))
                        .offset(
                            x: drop.xFraction * geo.size.width - geo.size.width / 2,
                            y: animate ? geo.size.height + 60 : -60
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
        .task {
            let gifData = await downloadGIFs()

            if gifData.isEmpty {
                // Fallback to emoji rain
                emojiDrops = (0..<60).map { _ in
                    EmojiDrop(
                        symbol: Self.emojiSymbols.randomElement()!,
                        xFraction: Double.random(in: 0...1),
                        size: CGFloat.random(in: 18...52),
                        duration: Double.random(in: 2...Self.maxDuration),
                        delay: Double.random(in: 0...Self.maxDelay),
                        endRotation: Double.random(in: -540...540)
                    )
                }
            } else {
                gifDrops = (0..<Self.dropCount).map { _ in
                    GIFDrop(
                        gifData: gifData.randomElement()!,
                        xFraction: Double.random(in: 0...1),
                        size: CGFloat.random(in: 40...80),
                        duration: Double.random(in: 2...Self.maxDuration),
                        delay: Double.random(in: 0...Self.maxDelay),
                        endRotation: Double.random(in: -180...180)
                    )
                }
            }

            animate = true

            let totalTime = Self.maxDuration + Self.maxDelay + 0.5
            try? await Task.sleep(for: .seconds(totalTime))
            onFinished?()
        }
    }

    private func downloadGIFs() async -> [Data] {
        await withTaskGroup(of: Data?.self) { group in
            for url in Self.gifURLs {
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
