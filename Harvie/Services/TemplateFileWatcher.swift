//
//  TemplateFileWatcher.swift
//  Harvie
//

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "TemplateFileWatcher")

@MainActor
final class TemplateFileWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var debounceTask: Task<Void, Never>?
    private let onChange: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func watch(directory: URL) {
        stop()

        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)

        // Watch the directory itself (catches new files, renames)
        let urls = [
            directory,
            directory.appendingPathComponent("template.html"),
            directory.appendingPathComponent("styles.css")
        ]

        for url in urls {
            let path = url.path
            guard fm.fileExists(atPath: path) else { continue }

            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            fileDescriptors.append(fd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .main
            )

            source.setEventHandler { [weak self] in
                self?.scheduleNotification()
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            sources.append(source)
        }

        #if DEBUG
        logger.debug("Watching \(urls.count) paths in \(directory.lastPathComponent)")
        #endif
    }

    nonisolated func stop() {
        MainActor.assumeIsolated {
            debounceTask?.cancel()
            debounceTask = nil

            for source in sources {
                source.cancel()
            }
            sources.removeAll()
            fileDescriptors.removeAll()
        }
    }

    private func scheduleNotification() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            onChange()
        }
    }
}
