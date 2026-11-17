import Foundation

/// Validate ZIP metadata before invoking macOS's extractor. No nested extraction.
enum ConnectionArchive {
    static func extract(_ archive: URL, to destination: URL, limit: Int64) throws {
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        let entries = try entries(data, limit: limit)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for entry in entries {
            try Task.checkCancellation()
            let target = destination.appending(path: entry.path)
            if entry.path.hasSuffix("/") {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                continue
            }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: target.path, contents: nil)
            let handle = try FileHandle(forWritingTo: target)
            defer { try? handle.close() }
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-p", archive.path, entry.path]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try process.run()
            defer {
                if process.isRunning { process.terminate() }
                try? pipe.fileHandleForReading.close()
            }
            var written: Int64 = 0
            while let chunk = try pipe.fileHandleForReading.read(upToCount: 65_536), !chunk.isEmpty {
                try Task.checkCancellation()
                written += Int64(chunk.count)
                guard written <= entry.bytes else { throw invalid }
                try handle.write(contentsOf: chunk)
            }
            process.waitUntilExit()
            guard process.terminationStatus == 0, written == entry.bytes else { throw invalid }
        }
    }

    static func validate(_ data: Data, limit: Int64) throws {
        _ = try entries(data, limit: limit)
    }

    private static func entries(_ data: Data, limit: Int64) throws -> [(path: String, bytes: Int64)] {
        func number(_ offset: Int, _ count: Int) throws -> Int64 {
            guard offset >= 0, offset + count <= data.count else { throw invalid }
            return (0..<count).reduce(0) { $0 | (Int64(data[offset + $1]) << ($1 * 8)) }
        }
        guard data.count >= 22 else { throw invalid }
        var end: Int?
        for offset in stride(from: data.count - 22, through: max(0, data.count - 65_557), by: -1) {
            if try number(offset, 4) == 0x06054b50,
               offset + 22 + Int(try number(offset + 20, 2)) == data.count { end = offset; break }
        }
        guard let end else { throw invalid }
        let count = Int(try number(end + 10, 2))
        guard try number(end + 4, 4) == 0, count <= 10_000 else { throw invalid }
        var offset = Int(try number(end + 16, 4))
        var total: Int64 = 0
        var paths = Set<String>()
        var entries: [(path: String, bytes: Int64)] = []
        for _ in 0..<count {
            guard try number(offset, 4) == 0x02014b50 else { throw invalid }
            let flags = try number(offset + 8, 2)
            let size = try number(offset + 24, 4)
            let nameLength = Int(try number(offset + 28, 2))
            let extraLength = Int(try number(offset + 30, 2))
            let commentLength = Int(try number(offset + 32, 2))
            let attributes = try number(offset + 38, 4)
            let fileType = (attributes >> 16) & 0xF000
            let start = offset + 46
            guard nameLength > 0, start + nameLength <= data.count,
                  let path = String(data: data[start..<(start + nameLength)], encoding: .utf8),
                  !path.hasPrefix("/"), !path.hasPrefix("-"), !path.contains("\\"), !path.contains("\0"),
                  !path.contains(where: { "*?[]".contains($0) }),
                  !path.split(separator: "/").contains(where: { $0 == ".." || $0 == "." }),
                  [0, 0x4000, 0x8000].contains(fileType),
                  flags & 1 == 0, size != 0xFFFFFFFF,
                  paths.insert(path.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw invalid }
            guard size <= limit - total else { throw ConnectionFiles.limitError }
            total += size
            entries.append((path, size))
            offset = start + nameLength + extraLength + commentLength
        }
        guard offset <= end else { throw invalid }
        return entries
    }

    private static var invalid: ConnectionError {
        ConnectionError("This ZIP is unsupported or contains unsafe paths. Use an unencrypted, non-ZIP64 archive without symbolic links or wildcard filenames.")
    }
}
