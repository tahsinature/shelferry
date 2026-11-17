import Foundation
import Testing
@testable import ShelferryApp

struct ConnectionSettingsTests {
    @Test func curlImportsHeadersAndRejectsCommands() throws {
        let result = try CurlRequestImport.parse("curl 'https://example.com/cb' -H 'Authorization: Bearer abc' -L")
        #expect(result.url == "https://example.com/cb")
        #expect(try ConnectionCredentials.headers(result.headers)["Authorization"] == "Bearer abc")
        #expect(throws: (any Error).self) { try CurlRequestImport.parse("curl https://example.com; rm file") }
        #expect(throws: (any Error).self) { try CurlRequestImport.parse("curl https://example.com --data payload") }
        #expect(throws: (any Error).self) { try CurlRequestImport.parse("curl https://example.com -X POST") }
    }

    @Test func rejectsUnsafeHeadersAndInvalidSettings() {
        #expect(throws: (any Error).self) { try ConnectionCredentials.headers("Authorization: token\rInjected: value") }
        #expect(throws: (any Error).self) { try ConnectionCredentials.headers("Host: another.example") }
        var settings = ShelfConnectionSettings()
        settings.source = .remote
        settings.location = "file:///etc/passwd"
        #expect(throws: (any Error).self) { try settings.validated() }
        settings.source = .folder
        settings.location = StoragePaths.dataDirectory.path
        #expect(throws: (any Error).self) { try settings.validated() }
    }

    @Test @MainActor func oldShelvesRemainRegularAndMissingConnectedReferencesRemainVisible() throws {
        let item = ShelfItem(fileURL: URL(fileURLWithPath: "/missing/file"))
        let old = SavedShelf(id: UUID(), name: "Old", lastUsed: Date(), items: [])
        let data = try JSONFile.encoder.encode(old)
        let shelf = Shelf(saved: try JSONFile.decoder.decode(SavedShelf.self, from: data))
        #expect(!shelf.connectionSettings.isConnected)
        var connected = item
        connected.connectionKey = "file"
        var settings = ShelfConnectionSettings()
        settings.source = .folder
        settings.mode = .mirror
        let referenceShelf = Shelf(saved: SavedShelf(id: UUID(), name: "Connected", lastUsed: Date(), items: [connected], connection: settings))
        referenceShelf.dropMissingFiles()
        #expect(referenceShelf.items.count == 1)
        referenceShelf.add([item])
        #expect(referenceShelf.items.count == 1)
        referenceShelf.remove([connected.id])
        #expect(referenceShelf.items.count == 1)
    }

    @Test func collectAlwaysUsesCopies() throws {
        var settings = ShelfConnectionSettings()
        settings.source = .folder
        settings.location = "/tmp/source"
        settings.storage = .reference
        #expect(try settings.validated().storage == .copy)
    }
}
