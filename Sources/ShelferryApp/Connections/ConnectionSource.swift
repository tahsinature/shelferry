import Foundation

struct ConnectionSource: Sendable {
    let root: URL
    let temporary: URL?

    static func load(_ settings: ShelfConnectionSettings, headers: [String: String]) async throws -> Self {
        if settings.source == .folder && !settings.archivesAsFolders {
            let root = URL(fileURLWithPath: settings.location)
            guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                throw ConnectionError("The source folder is unavailable. Saved files are kept. Reconnect it and retry.")
            }
            return Self(root: root, temporary: nil)
        }
        let temporary = FileManager.default.temporaryDirectory.appending(path: "Shelferry-" + UUID().uuidString)
        let root = temporary.appending(path: "contents")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            if settings.source == .folder {
                // Materialize only allowed entries before expanding top-level archives.
                let original = URL(fileURLWithPath: settings.location)
                let entries = try ConnectionFiles.scan(original, settings: settings)
                for entry in entries {
                    let destination = root.appending(path: entry.path)
                    if entry.isDirectory { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
                    else { try ConnectionFiles.copy(original.appending(path: entry.path), to: destination) }
                }
            } else {
                try await download(settings, headers: headers, to: root)
            }
            if settings.archivesAsFolders {
                let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey])
                for child in children where child.pathExtension.lowercased() == "zip" {
                    guard try child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
                    // Retain the .zip name to avoid collisions with a neighbouring folder.
                    let extracted = temporary.appending(path: UUID().uuidString)
                    try ConnectionArchive.extract(child, to: extracted, limit: settings.limitBytes)
                    try FileManager.default.removeItem(at: child)
                    try FileManager.default.moveItem(at: extracted, to: child)
                }
            }
            return Self(root: root, temporary: temporary)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func download(_ settings: ShelfConnectionSettings, headers: [String: String], to root: URL) async throws {
        guard let url = URL(string: settings.location) else { throw ConnectionError("Invalid source URL.") }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.allHTTPHeaderFields = headers
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 300
        let session = URLSession(configuration: configuration, delegate: SameOriginRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw ConnectionError("The server did not return an HTTP response.") }
        guard (200...299).contains(response.statusCode) else {
            throw ConnectionError("The source returned HTTP \(response.statusCode). Check the URL and authentication, then retry.")
        }
        guard response.expectedContentLength <= settings.limitBytes else { throw ConnectionFiles.limitError }
        var name = response.value(forHTTPHeaderField: "X-Filename") ?? response.suggestedFilename ?? "Download"
        name = (name as NSString).lastPathComponent
        if name.isEmpty || name == "." || name == ".." { name = "Download" }
        if response.mimeType == "application/zip", !(name as NSString).pathExtension.lowercased().elementsEqual("zip") { name += ".zip" }
        let destination = root.appending(path: name)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        var buffer = Data()
        var count: Int64 = 0
        for try await byte in bytes {
            count += 1
            guard count <= settings.limitBytes else { throw ConnectionFiles.limitError }
            buffer.append(byte)
            if buffer.count == 65_536 {
                try Task.checkCancellation()
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        try handle.write(contentsOf: buffer)
    }
}

/// Never forward user-supplied credentials to another origin through a redirect.
private final class SameOriginRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        let old = task.originalRequest?.url
        let new = request.url
        completionHandler(old?.scheme == new?.scheme && old?.host == new?.host && old?.port == new?.port ? request : nil)
    }
}
