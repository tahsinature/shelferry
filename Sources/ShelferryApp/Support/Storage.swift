import Foundation

enum StoragePaths {
    /// Shelferry data is isolated from Tooki and other applications.
    static var dataDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["SHELFERRY_DATA_DIR"], !custom.isEmpty {
            return URL(fileURLWithPath: custom)
        }
        return URL.applicationSupportDirectory.appending(path: "Shelferry")
    }
}

enum JSONFile {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func read(_ url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    /// Writes through symlinks (instead of replacing them) so dotfile links stay intact.
    static func write(_ data: Data, to url: URL) throws {
        let target = url.resolvingSymlinksInPath()
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: target, options: .atomic)
    }
}
