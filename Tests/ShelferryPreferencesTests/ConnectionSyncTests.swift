import Foundation
import Testing
@testable import ShelferryApp

struct ConnectionSyncTests {
    private func fixture() throws -> (root: URL, source: URL, storage: URL, settings: ShelfConnectionSettings) {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let source = root.appending(path: "source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        var settings = ShelfConnectionSettings()
        settings.source = .folder
        settings.location = source.path
        return (root, source, root.appending(path: "storage"), settings)
    }

    private func write(_ value: String, _ path: String, in source: URL) throws {
        let url = source.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: url)
    }

    @Test func collectVersionsOnlyChangedFilesAndPreservesDeletedFiles() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        try write("old", "folder/a.txt", in: f.source)
        try write("unchanged", "folder/b.txt", in: f.source)
        let first = try await ConnectionSync.prepare(settings: f.settings, headers: [:], previous: nil, directory: f.storage)
        try first.save(to: f.storage)
        try write("new", "folder/a.txt", in: f.source)
        try FileManager.default.removeItem(at: f.source.appending(path: "folder/b.txt"))
        let second = try await ConnectionSync.prepare(settings: f.settings, headers: [:], previous: first, directory: f.storage)
        #expect(second.items.count == 1)
        #expect(second.items.first?.id == first.items.first?.id)
        #expect(second.versions.count == 1)
        #expect(second.versions.first?.path == "folder/a.txt")
        #expect(second.entries.contains { $0.path == "folder/b.txt" })
        let old = second.root(in: f.storage).appending(path: try #require(second.versions.first).storedPath)
        #expect(try String(contentsOf: old, encoding: .utf8) == "old")
        let third = try await ConnectionSync.prepare(settings: f.settings, headers: [:], previous: second, directory: f.storage)
        #expect(third.versions.count == 1)
        #expect(third.generation == second.generation)
    }

    @Test func mirrorRemovesSourceDeletionsAndFiltersNestedFiles() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        var settings = f.settings
        settings.mode = .mirror
        settings.excludePatterns = "*.tmp"
        try write("keep", "nested/a.txt", in: f.source)
        try write("ignore", "nested/a.tmp", in: f.source)
        try write("hidden", ".secret", in: f.source)
        let first = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: nil, directory: f.storage)
        #expect(first.entries.count == 2)
        try FileManager.default.removeItem(at: f.source.appending(path: "nested"))
        let second = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: first, directory: f.storage)
        #expect(second.items.isEmpty)
        #expect(second.versions.isEmpty)
    }

    @Test func limitIncludesHistoryAndFailurePreservesCommittedState() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        var settings = f.settings
        settings.limitBytes = 5
        try write("old", "a.txt", in: f.source)
        let first = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: nil, directory: f.storage)
        try first.save(to: f.storage)
        try write("new", "a.txt", in: f.source)
        await #expect(throws: (any Error).self) {
            try await ConnectionSync.prepare(settings: settings, headers: [:], previous: first, directory: f.storage)
        }
        #expect(try ConnectionManifest.read(from: f.storage)?.generation == first.generation)
        #expect(try String(contentsOf: first.items[0].url, encoding: .utf8) == "old")
        let roots = try FileManager.default.contentsOfDirectory(atPath: f.storage.path)
        #expect(roots.count == 2) // One committed generation and state.json; no partial generation.
    }

    @Test func fileReplacingFolderKeepsIndividualOldVersions() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        try write("old", "entry/a.txt", in: f.source)
        let first = try await ConnectionSync.prepare(settings: f.settings, headers: [:], previous: nil, directory: f.storage)
        try FileManager.default.removeItem(at: f.source.appending(path: "entry"))
        try write("replacement", "entry", in: f.source)
        let second = try await ConnectionSync.prepare(settings: f.settings, headers: [:], previous: first, directory: f.storage)
        #expect(second.entries.count == 1)
        #expect(second.versions.first?.path == "entry/a.txt")
    }

    @Test func unavailableSourceDoesNotPublishEmptyMirror() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        var settings = f.settings
        settings.mode = .mirror
        try write("keep", "a.txt", in: f.source)
        let first = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: nil, directory: f.storage)
        try first.save(to: f.storage)
        try FileManager.default.removeItem(at: f.source)
        await #expect(throws: (any Error).self) {
            try await ConnectionSync.prepare(settings: settings, headers: [:], previous: first, directory: f.storage)
        }
        #expect(try ConnectionManifest.read(from: f.storage)?.items.count == 1)
    }

    @Test func referenceShelfDoesNotCopyFiles() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        var settings = f.settings
        settings.mode = .mirror
        settings.storage = .reference
        try write("original", "a.txt", in: f.source)
        let result = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: nil, directory: f.storage)
        #expect(result.items.first?.url.resolvingSymlinksInPath() == f.source.appending(path: "a.txt").resolvingSymlinksInPath())
        #expect(result.items.first?.ownsFile == false)
        #expect(result.storedBytes == 0)
    }

    @Test func rejectsSymlinksInsteadOfReadingOutsideSource() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        try FileManager.default.createSymbolicLink(at: f.source.appending(path: "link"), withDestinationURL: f.root)
        await #expect(throws: (any Error).self) {
            try await ConnectionSync.prepare(settings: f.settings, headers: [:], previous: nil, directory: f.storage)
        }
    }

    @Test func cleanupPreservesDetachedFilesThroughPathAliases() async throws {
        let f = try fixture()
        defer { try? FileManager.default.removeItem(at: f.root) }
        let kept = UUID().uuidString
        let abandoned = UUID().uuidString
        try write("keep", "\(kept)/current/file.txt", in: f.storage)
        try write("old", "\(abandoned)/current/file.txt", in: f.storage)
        let alias = f.root.appending(path: "alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: f.storage)
        let item = ShelfItem(savedFile: alias.appending(path: "\(kept)/current/file.txt"), text: nil, isLink: false)
        await ConnectionManifest.removeAbandonedGenerations(in: f.storage, keeping: nil, items: [item]).value
        #expect(item.exists)
        #expect(!FileManager.default.fileExists(atPath: f.storage.appending(path: abandoned).path))
    }
}
