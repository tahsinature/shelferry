import Foundation
import ShelferryProtocol

extension Shelf {
    /// CLI success means copies finished and their records were added, not just queued.
    func addConfirmed(_ urls: [URL], copy: Bool, isAvailable: () -> Bool) async throws {
        guard acceptsManualItems, !connection.isRefreshing else {
            throw ServiceError("This shelf is source-controlled or refreshing. Try a regular or idle Collect shelf.")
        }
        if copy { try await connection.checkManualStorage(manualStorageURLs + urls) }
        guard copy else { add(fileURLs: urls, mode: .original); return }
        var staged: [ShelfItem] = []
        for url in urls {
            let destination = ShelfStorage.newFolder().appending(path: url.lastPathComponent)
            let item = ShelfItem(copyOf: url, at: destination)
            guard !items.contains(where: { $0.dedupeKey == item.dedupeKey }),
                  !staged.contains(where: { $0.dedupeKey == item.dedupeKey }) else { continue }
            guard await ShelfStorage.copy(url, to: destination) else {
                staged.forEach { ShelfStorage.deleteFolder(of: $0.url) }
                throw ServiceError("Could not copy \(url.path). No files from this request were added.")
            }
            staged.append(item)
        }
        guard isAvailable(), acceptsManualItems, !connection.isRefreshing else {
            staged.forEach { ShelfStorage.deleteFolder(of: $0.url) }
            throw ServiceError("The shelf was closed while files were being copied.")
        }
        add(staged)
    }
}
