import Foundation

struct ConnectionManifest: Codable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var path: String
        var digest: String
        var bytes: Int64
        var isDirectory: Bool
    }
    struct Version: Codable, Identifiable, Sendable {
        var id = UUID()
        var path: String
        var storedPath: String
        var date: Date
        var bytes: Int64
    }

    var generation = UUID().uuidString
    var settings: ShelfConnectionSettings
    var entries: [Entry] = []
    var versions: [Version] = []
    var items: [ShelfItem] = []
    var lastRefresh = Date()
    var storedBytes: Int64 = 0

    static func directory(for id: UUID) -> URL {
        StoragePaths.dataDirectory.appending(path: "connected-shelves").appending(path: id.uuidString)
    }

    static func read(from directory: URL) throws -> Self? {
        let file = directory.appending(path: "state.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try JSONFile.decoder.decode(Self.self, from: Data(contentsOf: file))
    }

    func save(to directory: URL) throws {
        try JSONFile.write(JSONFile.encoder.encode(self), to: directory.appending(path: "state.json"))
    }

    func root(in directory: URL) -> URL { directory.appending(path: generation) }

    @discardableResult
    static func removeAbandonedGenerations(in directory: URL, keeping manifest: Self?, items: [ShelfItem]) -> Task<Void, Never> {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let itemPaths = items.map { $0.url.resolvingSymlinksInPath().path }
        let abandoned = folders.filter { folder in
            UUID(uuidString: folder.lastPathComponent) != nil && folder.lastPathComponent != manifest?.generation &&
            !itemPaths.contains { $0.hasPrefix(folder.resolvingSymlinksInPath().path + "/") }
        }
        return Task.detached(priority: .utility) {
            for folder in abandoned { try? FileManager.default.removeItem(at: folder) }
        }
    }
}
