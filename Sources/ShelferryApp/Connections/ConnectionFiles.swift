import CryptoKit
import Foundation

/// File IO stays off the main actor. Symbolic links are not traversed.
enum ConnectionFiles {
    static var fileManager: FileManager { FileManager.default }

    static func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 256 * 1024), !data.isEmpty {
            try Task.checkCancellation()
            digest.update(data: data)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func scan(_ root: URL, settings: ShelfConnectionSettings) throws -> [ConnectionManifest.Entry] {
        var entries: [ConnectionManifest.Entry] = []
        var bytes: Int64 = 0
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        func visit(_ directory: URL, prefix: String) throws {
            let children = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                try Task.checkCancellation()
                let name = child.lastPathComponent
                let path = prefix + name
                if !settings.includeHidden && name.hasPrefix(".") { continue }
                if matches(path, patterns: settings.excludePatterns) { continue }
                let values = try child.resourceValues(forKeys: keys)
                guard values.isSymbolicLink != true else {
                    throw ConnectionError("Symbolic links are not supported: \(path). Exclude this path to continue.")
                }
                if values.isDirectory == true {
                    entries.append(.init(path: path, digest: "", bytes: 0, isDirectory: true))
                    try visit(child, prefix: path + "/")
                } else if values.isRegularFile == true {
                    if !settings.includePatterns.isEmpty && !matches(path, patterns: settings.includePatterns) { continue }
                    let size = Int64(values.fileSize ?? 0)
                    guard size <= settings.limitBytes - bytes else { throw limitError }
                    bytes += size
                    entries.append(.init(path: path, digest: try hash(child), bytes: size, isDirectory: false))
                }
            }
        }
        try visit(root, prefix: "")
        return entries.sorted { $0.path < $1.path }
    }

    static func matches(_ path: String, patterns: String) -> Bool {
        patterns.split(separator: "\n").contains { line in
            let pattern = line.trimmingCharacters(in: .whitespaces)
            guard !pattern.isEmpty else { return false }
            let target = pattern.contains("/") ? path : (path as NSString).lastPathComponent
            return fnmatch(pattern, target, 0) == 0
        }
    }

    static func copy(_ source: URL, to destination: URL) throws {
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: destination)
    }

    static func size(_ url: URL) throws -> Int64 {
        if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory != true {
            return Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        let children = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey])
        return try children.reduce(0) { total, child in
            try Task.checkCancellation()
            if try child.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true { return total }
            return try total + size(child)
        }
    }

    static var limitError: ConnectionError {
        ConnectionError("Storage limit reached. Existing files are kept. Increase the limit or remove older versions, then retry.")
    }
}
