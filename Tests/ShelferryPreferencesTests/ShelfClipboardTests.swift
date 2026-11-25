import AppKit
import Testing
@testable import ShelferryApp

@MainActor
struct ShelfClipboardTests {
    @Test func copiesOnlyAvailableItemsAndReportsActualCount() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let urls = ["first.txt", "second.txt", "pending.txt"].map { directory.appending(path: $0) }
        for url in urls { try Data("test".utf8).write(to: url) }
        let items = urls.map { ShelfItem(fileURL: $0) }
        let missing = ShelfItem(fileURL: directory.appending(path: "missing.txt"))
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let clipboard = ShelfClipboard()

        clipboard.copy(items + [missing], excluding: [items[2].id], to: pasteboard)

        let copied = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
        #expect(copied == Array(urls.prefix(2)))
        #expect(clipboard.copiedCount == 2)
    }

    @Test func emptySelectionPreservesClipboardAndShowsNoConfirmation() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("Keep this", forType: .string)
        let clipboard = ShelfClipboard()

        clipboard.copy([], excluding: [], to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "Keep this")
        #expect(clipboard.copiedCount == nil)
    }
}
