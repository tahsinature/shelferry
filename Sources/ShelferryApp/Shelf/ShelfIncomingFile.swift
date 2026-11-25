import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Browsers can publish an image path before they finish writing its contents.
enum ShelfIncomingFile {
    static func isReadable(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return true }
        guard let type = UTType(filenameExtension: url.pathExtension),
              let supportedTypes = CGImageSourceCopyTypeIdentifiers() as? [String],
              supportedTypes.contains(type.identifier)
        else { return true }
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, options) != nil,
              CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
        else { return false }
        return true
    }

    static func waitUntilReadable(_ url: URL, timeout: Duration = .seconds(30)) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: timeout)
            repeat {
                if isReadable(url) { return true }
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return false }
            } while clock.now < deadline
            return false
        }.value
    }
}
