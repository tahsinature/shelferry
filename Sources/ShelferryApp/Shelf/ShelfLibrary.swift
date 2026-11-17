import Foundation
import ShelferryProtocol
import Observation

/// Every shelf, saved in Application Support so they come back after Shelferry restarts.
@MainActor
@Observable
final class ShelfLibrary {
    /// In the order they were made.
    private(set) var shelves: [Shelf] = []

    init(initialShelves: [Shelf] = []) {
        shelves = initialShelves
    }

    static let fileURL = StoragePaths.dataDirectory.appending(path: "shelves.json")
    /// Where the single shelf was saved before Shelferry had more than one.
    private static let oldFileURL = StoragePaths.dataDirectory.appending(path: "shelf.json")

    var isEmpty: Bool { shelves.isEmpty }
    var itemCount: Int { shelves.map(\.items.count).reduce(0, +) }
    var mostRecent: Shelf? { shelves.max { $0.lastUsed < $1.lastUsed } }

    func load() throws {
        shelves = try Self.readSaved().map(Shelf.init(saved:))
        shelves.forEach(watch)
        shelves.forEach { $0.connection.start() }
        let ownedFiles = shelves.flatMap(\.items).filter(\.ownsFile).map(\.url)
        ShelfStorage.deleteUnused(keeping: ownedFiles)
        save()
        try? FileManager.default.removeItem(at: Self.oldFileURL)
    }

    func newShelf(named name: String? = nil) -> Shelf {
        let shelf = Shelf(name: name ?? nextName())
        watch(shelf)
        shelves.append(shelf)
        save()
        return shelf
    }

    /// Takes the shelf away for good. Shelferry's own copies on it are deleted.
    func remove(_ shelf: Shelf) {
        shelf.connection.stop()
        shelf.settingsWindow.close()
        ConnectionCredentials.delete(shelf.connectionSettings.credentialID)
        shelf.imageConversion?.discard()
        shelf.clear()
        shelves.removeAll { $0.id == shelf.id }
        save()
        try? FileManager.default.removeItem(at: ConnectionManifest.directory(for: shelf.id))
    }

    func dropMissingFiles() {
        shelves.forEach { $0.dropMissingFiles() }
    }

    /// Finds a shelf by its id or its name (any case).
    func shelf(matching reference: String) -> Shelf? {
        shelves.first { $0.id.uuidString.caseInsensitiveCompare(reference) == .orderedSame }
            ?? shelves.first { $0.name.caseInsensitiveCompare(reference) == .orderedSame }
    }

    /// What's saved on disk. Also read by the `shelferry shelf list` command.
    static func readSaved() throws -> [SavedShelf] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONFile.decoder.decode([SavedShelf].self, from: Data(contentsOf: fileURL))
    }

    /// Explicit CLI acknowledgement checks disk persistence as well as in-memory state.
    func flush() throws {
        try JSONFile.write(JSONFile.encoder.encode(shelves.map(\.saved)), to: Self.fileURL)
    }

    private func watch(_ shelf: Shelf) {
        shelf.onChange = { [weak self] in self?.save() }
    }

    private func save() {
        do { try flush() } catch { NSLog("Shelferry save failed: %@", error.localizedDescription) }
    }

    /// "Shelf 1", "Shelf 2", …, reusing the lowest number that's free.
    private func nextName() -> String {
        let names = Set(shelves.map(\.name))
        let number = (1...).first { !names.contains("Shelf \($0)") } ?? 1
        return "Shelf \(number)"
    }
}

struct SavedShelf: Codable {
    var id: UUID
    var name: String
    var lastUsed: Date
    var items: [ShelfItem]
    var connection: ShelfConnectionSettings? = nil
}
