import Foundation
import ShelferryProtocol

@MainActor
final class CommandHandler {
    var onSettings: () -> Void = {}
    let windows: ShelfWindows
    init(windows: ShelfWindows) {
        self.windows = windows
    }
    var library: ShelfLibrary { windows.library }

    func handle(_ request: Request) async -> Response {
        do {
            guard request.version == 1 else { throw ServiceError("Unsupported protocol version.") }
            switch request.command {
            case "ping": return Response()
            case "list":
                library.dropMissingFiles()
                return Response(shelves: library.shelves.sorted { $0.lastUsed > $1.lastUsed }.map(record))
            case "items":
                let shelf = try find(request.shelf)
                shelf.dropMissingFiles()
                return Response(items: shelf.items.map { ItemRecord(id: $0.id.uuidString, path: $0.path, isCopy: $0.isCopy) })
            case "new":
                let shelf = windows.newShelf(named: request.name, focus: false)
                try library.flush()
                return Response(shelves: [record(shelf)])
            case "add":
                guard !request.paths.isEmpty else { throw ServiceError("No files supplied.") }
                let urls = request.paths.map { URL(fileURLWithPath: $0) }
                for url in urls where !FileManager.default.fileExists(atPath: url.path) {
                    throw ServiceError("File does not exist: \(url.path)")
                }
                let shelf: Shelf
                if request.shelf == "new" { shelf = library.newShelf() }
                else if let reference = request.shelf { shelf = try find(reference) }
                else { shelf = library.mostRecent ?? library.newShelf() }
                try await shelf.addConfirmed(urls, copy: request.copy) {
                    self.library.shelves.contains { $0.id == shelf.id }
                }
                windows.show(shelf)
                try library.flush()
                return Response(shelves: [record(shelf)])
            case "show", "hide", "toggle":
                if let reference = request.shelf {
                    let shelf = try find(reference)
                    if request.command == "hide" || (request.command == "toggle" && windows.isVisible(shelf)) { windows.hide(shelf) }
                    else { windows.show(shelf) }
                } else if request.command == "toggle" { windows.toggleAll() }
                else if request.command == "hide" { windows.hideAll() }
                else { if library.isEmpty { windows.newShelf(focus: false) } else { windows.showAll() } }
            // Compatibility for older launchers; the visual manager has been removed.
            case "manager": windows.toggleAll()
            case "settings": onSettings()
            case "rename":
                let shelf = try find(request.shelf)
                guard let name = request.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ServiceError("A name is required.") }
                shelf.rename(to: name)
                try library.flush()
                return Response(shelves: [record(shelf)])
            case "clear", "delete":
                guard request.confirmed else { throw ServiceError("Pass --yes to delete Shelferry-owned copies.") }
                let shelf = try find(request.shelf)
                if request.command == "delete" { windows.removeImmediately(shelf) }
                else {
                    guard !shelf.connectionSettings.isConnected else {
                        throw ServiceError("Disconnect the source in Shelf Settings before clearing connected items.")
                    }
                    shelf.clear()
                }
            default: throw ServiceError("Unknown command: \(request.command)")
            }
            try library.flush()
            return Response()
        } catch { return Response(error: error.localizedDescription) }
    }
    private func record(_ shelf: Shelf) -> ShelfRecord {
        ShelfRecord(id: shelf.id.uuidString, name: shelf.name, count: shelf.items.count)
    }
    private func find(_ reference: String?) throws -> Shelf {
        guard let reference else { throw ServiceError("A shelf ID or name is required.") }
        if let shelf = library.shelves.first(where: { $0.id.uuidString.caseInsensitiveCompare(reference) == .orderedSame }) { return shelf }
        let matches = library.shelves.filter { $0.name.caseInsensitiveCompare(reference) == .orderedSame }
        guard matches.count == 1, let shelf = matches.first else {
            throw ServiceError(matches.isEmpty ? "Shelf not found: \(reference)" : "Several shelves have that name. Use its ID.")
        }
        return shelf
    }
}
