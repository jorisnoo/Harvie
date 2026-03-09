//
//  LogoStorage.swift
//  Harvie
//

import AppKit
import Foundation

enum LogoStorage {
    private static let maxDimension: CGFloat = 512
    private static let fileName = "company-logo.png"

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Harvie")
        return appDir.appendingPathComponent(fileName)
    }

    static func save(_ image: NSImage) throws {
        let resized = resize(image, maxDimension: maxDimension)

        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw LogoError.conversionFailed
        }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try pngData.write(to: fileURL)
    }

    static func load() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    static func loadImage() -> NSImage? {
        guard let data = load() else { return nil }
        return NSImage(data: data)
    }

    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func dataURI() -> String? {
        guard let data = load() else { return nil }
        return "data:image/png;base64,\(data.base64EncodedString())"
    }

    private static func resize(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size

        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()

        return resized
    }

    enum LogoError: Error, LocalizedError {
        case conversionFailed

        var errorDescription: String? {
            switch self {
            case .conversionFailed:
                return "Failed to convert image to PNG."
            }
        }
    }
}
