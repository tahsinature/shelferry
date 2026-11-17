import Foundation
import Observation

@MainActor @Observable
final class ShelfConnection {
    private(set) var manifest: ConnectionManifest?
    private(set) var isRefreshing = false
    private(set) var error: String?
    @ObservationIgnored private weak var shelf: Shelf?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var stopped = false
    @ObservationIgnored private var revision = UUID()

    init(shelf: Shelf) { self.shelf = shelf }
    var lastRefresh: Date? { manifest?.lastRefresh }
    var storedBytes: Int64 { manifest?.storedBytes ?? 0 }
    var versions: [ConnectionManifest.Version] { manifest?.versions.reversed() ?? [] }

    func report(_ error: any Error) { self.error = error.localizedDescription }

    func checkManualStorage(_ urls: [URL]) async throws {
        guard let shelf, shelf.connectionSettings.isConnected else { return }
        let limit = shelf.connectionSettings.limitBytes
        let stored = storedBytes
        let size = try await Task.detached(priority: .utility) {
            try urls.reduce(Int64(0)) { try $0 + ConnectionFiles.size($1) }
        }.value
        guard size <= limit - stored else { throw ConnectionFiles.limitError }
    }

    func start() {
        guard let shelf else { return }
        stopped = false
        do {
            manifest = try ConnectionManifest.read(from: ConnectionManifest.directory(for: shelf.id))
            if let manifest, shelf.connectionSettings.isConnected {
                shelf.replaceConnectedItems(manifest.items, removeManual: false)
            }
            ConnectionManifest.removeAbandonedGenerations(in: ConnectionManifest.directory(for: shelf.id), keeping: manifest, items: shelf.items)
        } catch {
            self.error = "Could not read saved connection state. Existing files are kept. \(error.localizedDescription)"
            return
        }
        schedule()
        if shelf.connectionSettings.isConnected && shelf.connectionSettings.automaticRefresh && !shelf.connectionSettings.paused { refresh() }
    }

    func apply(_ settings: ShelfConnectionSettings, headers: String) throws {
        guard let shelf, !isRefreshing, shelf.copyingIDs.isEmpty, shelf.imageConversion == nil else {
            throw ConnectionError("Wait for the current operation to finish before changing shelf settings.")
        }
        var validated = try settings.validated()
        if validated.usesReferences && !versions.isEmpty {
            throw ConnectionError("Export or clear older versions before switching to references.")
        }
        _ = try ConnectionCredentials.headers(headers)
        if validated.source == .remote && !headers.isEmpty {
            let id = shelf.connectionSettings.credentialID ?? UUID().uuidString
            try ConnectionCredentials.write(headers, id: id)
            validated.credentialID = id
        } else {
            validated.credentialID = nil
        }
        revision = UUID()
        if validated.source == .regular, shelf.connectionSettings.isConnected, var saved = manifest {
            saved.items = []
            saved.entries = []
            saved.storedBytes = saved.versions.reduce(0) { $0 + $1.bytes }
            try saved.save(to: ConnectionManifest.directory(for: shelf.id))
            manifest = saved
            shelf.detachConnectedItems()
        }
        shelf.connectionSettings = validated
        shelf.onChange()
        error = nil
        schedule()
        if validated.isConnected { refresh() }
    }

    func togglePause() {
        guard let shelf else { return }
        shelf.connectionSettings.paused.toggle()
        shelf.onChange()
        if shelf.connectionSettings.paused {
            revision = UUID()
            refreshTask?.cancel()
        }
        schedule()
        if !shelf.connectionSettings.paused { refresh() }
    }

    func refresh() {
        guard let shelf, !stopped, !isRefreshing, shelf.connectionSettings.isConnected else { return }
        guard shelf.copyingIDs.isEmpty, shelf.imageConversion == nil else {
            error = "Wait for the current file operation to finish, then refresh."
            return
        }
        let settings = shelf.connectionSettings
        let directory = ConnectionManifest.directory(for: shelf.id)
        let previous = manifest
        let token = revision
        let manual = shelf.items.filter { $0.connectionKey == nil && $0.ownsFile }.map(\.url)
        isRefreshing = true
        error = nil
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { isRefreshing = false; refreshTask = nil }
            do {
                let headers = try ConnectionCredentials.headers(ConnectionCredentials.read(settings.credentialID))
                let worker = Task.detached(priority: .utility) {
                    let bytes = try manual.reduce(Int64(0)) { try $0 + ConnectionFiles.size($1) }
                    return try await ConnectionSync.prepare(settings: settings, headers: headers, previous: previous,
                                                            directory: directory, manualBytes: settings.mode == .mirror ? 0 : bytes)
                }
                let prepared = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled, revision == token, !stopped else {
                    if prepared.generation != previous?.generation {
                        try? FileManager.default.removeItem(at: prepared.root(in: directory))
                    }
                    return
                }
                do { try prepared.save(to: directory) }
                catch {
                    if prepared.generation != previous?.generation {
                        try? FileManager.default.removeItem(at: prepared.root(in: directory))
                    }
                    throw error
                }
                manifest = prepared
                shelf.replaceConnectedItems(prepared.items, removeManual: settings.mode == .mirror)
                shelf.onChange()
                // Keep the old URLs alive briefly for a drag destination still reading them.
                if let previous, previous.generation != prepared.generation {
                    let oldRoot = previous.root(in: directory)
                    let isStillUsed = shelf.items.contains { $0.path.hasPrefix(oldRoot.path + "/") }
                    if !isStillUsed { Task {
                        try? await Task.sleep(for: .seconds(60))
                        try? FileManager.default.removeItem(at: oldRoot)
                    } }
                }
            } catch is CancellationError {
                // Pausing keeps the last committed generation.
            } catch {
                self.error = error.localizedDescription + " Existing shelf items are kept."
            }
        }
    }

    func versionURL(_ version: ConnectionManifest.Version) -> URL? {
        guard let shelf, let manifest else { return nil }
        return manifest.root(in: ConnectionManifest.directory(for: shelf.id)).appending(path: version.storedPath)
    }

    func clearHistory() throws {
        guard let shelf, var updated = manifest, !isRefreshing else { return }
        let directory = ConnectionManifest.directory(for: shelf.id)
        updated.storedBytes -= updated.versions.reduce(0) { $0 + $1.bytes }
        updated.versions = []
        try updated.save(to: directory)
        manifest = updated
        try? FileManager.default.removeItem(at: updated.root(in: directory).appending(path: "versions"))
        error = nil
    }

    func stop() {
        stopped = true
        revision = UUID()
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
    }

    private func schedule() {
        timer?.invalidate()
        timer = nil
        guard let settings = shelf?.connectionSettings, settings.isConnected,
              settings.automaticRefresh, !settings.paused else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Double(settings.refreshSeconds), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }
}
