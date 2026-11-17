import Foundation
import Darwin

/// Private, same-user Unix socket. The app is the only process that writes shelf data.
public enum LocalSocket {
    public static var directory: String {
        ProcessInfo.processInfo.environment["SHELFERRY_SOCKET_DIR"] ?? "/tmp/shelferry-\(getuid())"
    }
    public static var path: String { directory + "/service.sock" }
    public static let maximumMessageSize = 1_048_576

    public static func prepareDirectory() throws {
        if mkdir(directory, 0o700) != 0 && errno != EEXIST { throw failure("Create IPC directory") }
        var info = stat()
        guard lstat(directory, &info) == 0, info.st_uid == getuid(),
              info.st_mode & S_IFMT == S_IFDIR, info.st_mode & 0o077 == 0 else {
            throw ServiceError("IPC directory must be owned by you, private (0700), and not a symlink.")
        }
    }

    public static func address() throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw ServiceError("IPC socket path is too long.")
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    public static func configure(_ fd: Int32) {
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        var timeout = timeval(tv_sec: 120, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    }

    public static func connect() throws -> Int32 {
        try prepareDirectory()
        var addr = try address()
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw failure("Create socket") }
        configure(fd)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else { Darwin.close(fd); throw failure("Connect to Shelferry") }
        var uid: uid_t = 0; var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else {
            Darwin.close(fd); throw ServiceError("Shelferry service belongs to another user.")
        }
        return fd
    }

    public static func send<T: Encodable>(_ value: T, to fd: Int32) throws {
        var data = try JSONEncoder().encode(value)
        guard data.count < maximumMessageSize else { throw ServiceError("Request is too large.") }
        data.append(10)
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw failure("Write response") }
                offset += count
            }
        }
    }

    public static func receive<T: Decodable>(_ type: T.Type, from fd: Int32) throws -> T {
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 8192)
        while data.count < maximumMessageSize {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw ServiceError("Connection ended or timed out. Check Shelferry before retrying a change.") }
            if let end = buffer.prefix(count).firstIndex(of: 10) {
                guard data.count + end < maximumMessageSize else {
                    throw ServiceError("Message exceeds the 1 MiB limit.")
                }
                data.append(contentsOf: buffer.prefix(end))
                return try JSONDecoder().decode(type, from: data)
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        throw ServiceError("Message exceeds the 1 MiB limit.")
    }

    public static func failure(_ operation: String) -> ServiceError {
        ServiceError("\(operation): \(String(cString: strerror(errno)))")
    }
}
