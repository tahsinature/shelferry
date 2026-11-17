import Foundation

struct ShelfConnectionSettings: Codable, Equatable, Sendable {
    enum Source: String, Codable, CaseIterable { case regular = "Regular", folder = "Folder", remote = "Remote" }
    enum Mode: String, Codable, CaseIterable { case mirror = "Mirror", collect = "Collect" }
    enum Storage: String, Codable, CaseIterable { case copy = "Copy", reference = "Reference" }

    var source: Source = .regular
    var location = ""
    var mode: Mode = .collect
    var storage: Storage = .copy
    var archivesAsFolders = false
    var automaticRefresh = true
    var refreshSeconds = 60
    var paused = false
    var includeHidden = false
    var includePatterns = ""
    var excludePatterns = ""
    var limitBytes: Int64 = 1_000_000_000
    // Headers, including credentials, are stored together in Keychain, never in this record.
    var credentialID: String?

    var isConnected: Bool { source != .regular }
    var usesReferences: Bool { source == .folder && mode == .mirror && storage == .reference }

    func validated() throws -> Self {
        var result = self
        result.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limitBytes > 0 else { throw ConnectionError("Enter a storage limit greater than zero.") }
        guard (5...86_400).contains(refreshSeconds) else {
            throw ConnectionError("Choose a refresh interval between 5 seconds and 24 hours.")
        }
        if source == .folder {
            guard result.location.hasPrefix("/") || result.location.hasPrefix("~/") else {
                throw ConnectionError("Choose an absolute folder path.")
            }
            result.location = (result.location as NSString).expandingTildeInPath
            let sourcePath = URL(fileURLWithPath: result.location).resolvingSymlinksInPath().path
            let ownPath = StoragePaths.dataDirectory.resolvingSymlinksInPath().path
            guard sourcePath != ownPath, !sourcePath.hasPrefix(ownPath + "/"), !ownPath.hasPrefix(sourcePath + "/") else {
                throw ConnectionError("Choose a folder outside Shelferry's storage, not a parent of it.")
            }
        }
        if source == .remote {
            guard let url = URL(string: result.location), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil, url.user == nil, url.password == nil else {
                throw ConnectionError("Enter an HTTP or HTTPS URL. Put authentication in request headers.")
            }
        }
        if !result.usesReferences { result.storage = .copy }
        if result.usesReferences { result.archivesAsFolders = false }
        return result
    }
}

struct ConnectionError: LocalizedError, Sendable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
