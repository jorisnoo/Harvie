//
//  TemplateFileWatcher.swift
//  Harvie
//

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.harvie", category: "TemplateFileWatcher")

@MainActor
final class TemplateFileWatcher {
    private static let watchedFileNames = ["template.html", "styles.css"]

    // Guarded by `lock`, not the main actor: `stop()` must work from any thread (an
    // owner's deinit may run off the main actor), and dispatch sources and tasks can be
    // cancelled from any thread. Each stop starts a new generation, which invalidates
    // callbacks still in flight from the previous watch.
    nonisolated(unsafe) private let lock = NSLock()
    nonisolated(unsafe) private var sources: [URL: DispatchSourceFileSystemObject] = [:]
    nonisolated(unsafe) private var pendingNotification: Task<Void, Never>?
    nonisolated(unsafe) private var currentGeneration = 0

    private var directory: URL?
    private let onChange: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func watch(directory: URL) {
        stop()

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory

        // Watch the directory itself (catches new files, renames) and each template file.
        let generation = self.generation
        startWatching(directory, generation: generation)
        for url in fileURLs(in: directory) {
            startWatching(url, generation: generation)
        }

        #if DEBUG
        logger.debug("Watching \(directory.lastPathComponent)")
        #endif
    }

    /// Safe from any thread.
    nonisolated func stop() {
        let (cancelled, notification) = lock.withLock { () -> ([DispatchSourceFileSystemObject], Task<Void, Never>?) in
            defer {
                sources.removeAll()
                pendingNotification = nil
                currentGeneration += 1
            }
            return (Array(sources.values), pendingNotification)
        }
        cancelled.forEach { $0.cancel() }
        notification?.cancel()
    }

    // MARK: - Private

    private var generation: Int {
        lock.withLock { currentGeneration }
    }

    private func source(for url: URL) -> DispatchSourceFileSystemObject? {
        lock.withLock { sources[url] }
    }

    private func fileURLs(in directory: URL) -> [URL] {
        Self.watchedFileNames.map { directory.appendingPathComponent($0) }
    }

    @discardableResult
    private func startWatching(_ url: URL, generation: Int) -> Bool {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return false }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.handleEvent(at: url, generation: generation)
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()

        // Register unless the watch was stopped meanwhile.
        let (accepted, replaced) = lock.withLock { () -> (Bool, DispatchSourceFileSystemObject?) in
            guard generation == currentGeneration else { return (false, nil) }
            return (true, sources.updateValue(source, forKey: url))
        }
        replaced?.cancel()
        if !accepted {
            source.cancel()
        }
        return accepted
    }

    private func handleEvent(at url: URL, generation: Int) {
        guard generation == self.generation, let watched = source(for: url) else { return }

        if url == directory {
            // Template files created after the watch began get their own watch.
            for file in fileURLs(in: url) where source(for: file) == nil {
                startWatching(file, generation: generation)
            }
        } else if !watched.data.isDisjoint(with: [.delete, .rename]) {
            // Editors often save by writing a new file and renaming it over the old one.
            // The descriptor still points at the replaced file, so watch the path afresh.
            lock.withLock { sources.removeValue(forKey: url) }?.cancel()
            rewatch(url, generation: generation)
        }

        scheduleNotification(generation: generation)
    }

    /// Re-establishes a file watch after a short delay, retrying while the file is
    /// momentarily missing mid-save. If it stays gone, the directory watch picks it up
    /// once it reappears.
    private func rewatch(_ url: URL, generation: Int, attempt: Int = 1) {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100 * attempt))
            guard let self, generation == self.generation, self.source(for: url) == nil else { return }
            if self.startWatching(url, generation: generation) {
                // The replacement may have landed after the last notification fired.
                self.scheduleNotification(generation: generation)
            } else if attempt < 5 {
                self.rewatch(url, generation: generation, attempt: attempt + 1)
            }
        }
    }

    private func scheduleNotification(generation: Int) {
        let task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self, generation == self.generation else { return }
            self.onChange()
        }
        let previous = lock.withLock { () -> Task<Void, Never>? in
            defer { pendingNotification = task }
            return pendingNotification
        }
        previous?.cancel()
    }
}
