import AppKit
import Testing
@testable import ShelferryApp

@MainActor
struct ShelfIncomingFileTests {
    private func imageData() throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 10, pixelsHigh: 10,
                                                  bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                                  bytesPerRow: 0, bitsPerPixel: 0))
        return try #require(bitmap.representation(using: .jpeg, properties: [:]))
    }

    @Test(arguments: [ShelfAddMode.original, .copy])
    func delayedImageFinishesWithCorrectBytesAndPreviewRevision(mode: ShelfAddMode) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "delayed.jpg")
        try Data().write(to: url)
        let shelf = Shelf(name: "Incoming test")
        defer { shelf.remove(Set(shelf.items.map(\.id))) }
        shelf.add(fileURLs: [url], mode: mode)
        #expect(shelf.receivingIDs.count == 1)
        #expect(shelf.totalBytes == 0)
        let data = try imageData()
        try data.prefix(20).write(to: url)
        try await Task.sleep(for: .milliseconds(150))
        #expect(shelf.receivingIDs.count == 1)
        try data.prefix(data.count / 2).write(to: url)
        #expect(!ShelfIncomingFile.isReadable(url))
        try data.write(to: url, options: .atomic)
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !shelf.copyingIDs.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        let item = try #require(shelf.items.first)
        #expect(shelf.copyingIDs.isEmpty)
        #expect(shelf.receivingIDs.isEmpty)
        #expect(shelf.totalBytes == Int64(data.count))
        #expect(item.conversionRevision != nil)
        #expect(try Data(contentsOf: item.url) == data)
    }

    @Test func incompleteImageTimesOutButEmptyTextIsValid() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = directory.appending(path: "empty.jpg")
        let text = directory.appending(path: "empty.txt")
        try Data().write(to: image)
        try Data().write(to: text)
        #expect(ShelfIncomingFile.isReadable(text))
        #expect(await !ShelfIncomingFile.waitUntilReadable(image, timeout: .milliseconds(150)))
    }
}
