import Foundation
import Testing
@testable import ShelferryApp

struct ConnectionArchiveTests {
    @Test func extractsZipAsFolderAndVersionsIndividualFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "source")
        let contents = root.appending(path: "contents")
        let storage = root.appending(path: "storage")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let file = contents.appending(path: "note.txt")
        let archive = source.appending(path: "bundle.zip")
        func zip(_ text: String) throws {
            try Data(text.utf8).write(to: file)
            try? FileManager.default.removeItem(at: archive)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-q", archive.path, "note.txt"]
            process.currentDirectoryURL = contents
            try process.run()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
        }
        var settings = ShelfConnectionSettings()
        settings.source = .folder
        settings.location = source.path
        settings.archivesAsFolders = true
        try zip("first")
        let first = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: nil, directory: storage)
        #expect(first.entries.contains { $0.path == "bundle.zip/note.txt" })
        try zip("second")
        let second = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: first, directory: storage)
        #expect(second.versions.first?.path == "bundle.zip/note.txt")
        #expect(try String(contentsOf: second.items[0].url.appending(path: "note.txt"), encoding: .utf8) == "second")
        settings.archivesAsFolders = false
        let raw = try await ConnectionSync.prepare(settings: settings, headers: [:], previous: second, directory: storage)
        #expect(raw.entries.count == 1)
        #expect(raw.entries.first?.isDirectory == false)
    }

    @Test func rejectsTraversalSymlinksAndOversizedArchiveMetadata() {
        #expect(throws: (any Error).self) { try ConnectionArchive.validate(zipMetadata(path: "../escape"), limit: 100) }
        #expect(throws: (any Error).self) { try ConnectionArchive.validate(zipMetadata(path: "/absolute"), limit: 100) }
        #expect(throws: (any Error).self) { try ConnectionArchive.validate(zipMetadata(path: "link", mode: 0xA000), limit: 100) }
        #expect(throws: (any Error).self) { try ConnectionArchive.validate(zipMetadata(path: "large", bytes: 101), limit: 100) }
    }

    private func zipMetadata(path: String, bytes: UInt32 = 1, mode: UInt32 = 0x8000) -> Data {
        var central = Data(repeating: 0, count: 46)
        func write(_ value: UInt32, at offset: Int, count: Int, in data: inout Data) {
            for index in 0..<count { data[offset + index] = UInt8(truncatingIfNeeded: value >> (index * 8)) }
        }
        write(0x02014b50, at: 0, count: 4, in: &central)
        write(bytes, at: 24, count: 4, in: &central)
        write(UInt32(path.utf8.count), at: 28, count: 2, in: &central)
        write(mode << 16, at: 38, count: 4, in: &central)
        central.append(Data(path.utf8))
        var end = Data(repeating: 0, count: 22)
        write(0x06054b50, at: 0, count: 4, in: &end)
        write(1, at: 10, count: 2, in: &end)
        central.append(end)
        return central
    }
}
