import Foundation

/// Prepares a complete generation. Publishing its manifest is a separate, atomic step.
enum ConnectionSync {
    static func prepare(settings: ShelfConnectionSettings, headers: [String: String],
                        previous: ConnectionManifest?, directory: URL, manualBytes: Int64 = 0) async throws -> ConnectionManifest {
        let source = try await ConnectionSource.load(settings, headers: headers)
        defer { if let temporary = source.temporary { try? FileManager.default.removeItem(at: temporary) } }
        if settings.usesReferences {
            return try references(source.root, settings: settings, previous: previous)
        }
        let incoming = try ConnectionFiles.scan(source.root, settings: settings)
        let sameSource = previous?.settings.source == settings.source && previous?.settings.location == settings.location

        let old = previous?.entries ?? []
        let oldByPath = Dictionary(uniqueKeysWithValues: old.map { ($0.path, $0) })
        let incomingByPath = Dictionary(uniqueKeysWithValues: incoming.map { ($0.path, $0) })
        var combined = sameSource && settings.mode == .collect ? oldByPath : [:]
        for entry in incoming {
            if !entry.isDirectory {
                combined = combined.filter { !$0.key.hasPrefix(entry.path + "/") }
            }
            combined[entry.path] = entry
        }
        var manifest = ConnectionManifest(settings: settings)
        manifest.entries = combined.values.sorted { $0.path < $1.path }
        manifest.versions = previous?.versions ?? []
        if var previous, previous.settings == settings, previous.entries == manifest.entries {
            var verification = ShelfConnectionSettings()
            verification.includeHidden = true
            verification.limitBytes = settings.limitBytes
            let current = previous.root(in: directory).appending(path: "current")
            if let actual = try? ConnectionFiles.scan(current, settings: verification), actual == previous.entries {
                guard manualBytes <= settings.limitBytes - previous.storedBytes else { throw ConnectionFiles.limitError }
                previous.lastRefresh = Date()
                return previous
            }
        }
        let root = manifest.root(in: directory)
        let current = root.appending(path: "current")
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        do {
            let previousRoot = previous?.root(in: directory)
            let previousCurrent = previousRoot?.appending(path: "current")
            let oldVersions = previousRoot?.appending(path: "versions")
            if let oldVersions, FileManager.default.fileExists(atPath: oldVersions.path) {
                try ConnectionFiles.copy(oldVersions, to: root.appending(path: "versions"))
            }
            var used = manualBytes + manifest.versions.reduce(Int64(0)) { $0 + $1.bytes }
            let filesToArchive = old.filter { entry in
                guard !entry.isDirectory, previous?.settings.usesReferences != true else { return false }
                let replacement = combined[entry.path]
                return (!sameSource || settings.mode == .collect) && replacement?.digest != entry.digest
            }
            for entry in filesToArchive {
                guard let previousCurrent else { continue }
                let id = UUID()
                let storedPath = "versions/\(id.uuidString)/\((entry.path as NSString).lastPathComponent)"
                guard entry.bytes <= settings.limitBytes - used else { throw ConnectionFiles.limitError }
                used += entry.bytes
                try ConnectionFiles.copy(previousCurrent.appending(path: entry.path), to: root.appending(path: storedPath))
                manifest.versions.append(.init(id: id, path: entry.path, storedPath: storedPath,
                                              date: previous?.lastRefresh ?? Date(), bytes: entry.bytes))
            }
            for entry in manifest.entries {
                try Task.checkCancellation()
                let destination = current.appending(path: entry.path)
                if entry.isDirectory {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    continue
                }
                guard entry.bytes <= settings.limitBytes - used else { throw ConnectionFiles.limitError }
                used += entry.bytes
                let from: URL
                if incomingByPath[entry.path] != nil { from = source.root.appending(path: entry.path) }
                else if let previousCurrent { from = previousCurrent.appending(path: entry.path) }
                else { throw ConnectionError("The saved source state is missing. Retry the refresh.") }
                try ConnectionFiles.copy(from, to: destination)
                guard try ConnectionFiles.hash(destination) == entry.digest,
                      try ConnectionFiles.size(destination) == entry.bytes else {
                    throw ConnectionError("A source file changed during refresh. Existing files are kept. Retry when copying finishes.")
                }
            }
            manifest.storedBytes = used - manualBytes
            let topLevel = manifest.entries.filter { !$0.path.contains("/") }
            manifest.items = topLevel.map { entry in
                var item = ShelfItem(savedFile: current.appending(path: entry.path), text: nil, isLink: false)
                item.connectionKey = entry.path
                item.id = previous?.items.first { $0.connectionKey == entry.path }?.id ?? UUID()
                return item
            }
            return manifest
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    private static func references(_ root: URL, settings: ShelfConnectionSettings,
                                   previous: ConnectionManifest?) throws -> ConnectionManifest {
        var manifest = ConnectionManifest(settings: settings)
        // A folder reference always exposes the original folder in full; filters apply to top-level items.
        let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey])
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = child.lastPathComponent
            if !settings.includeHidden && name.hasPrefix(".") { continue }
            if ConnectionFiles.matches(name, patterns: settings.excludePatterns) { continue }
            if !settings.includePatterns.isEmpty && !ConnectionFiles.matches(name, patterns: settings.includePatterns) { continue }
            if try child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true { continue }
            var item = ShelfItem(fileURL: child)
            item.connectionKey = name
            item.id = previous?.items.first { $0.connectionKey == name }?.id ?? UUID()
            manifest.items.append(item)
        }
        return manifest
    }
}
