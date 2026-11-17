import Foundation
import Darwin
import ShelferryProtocol

/// A single serial accept loop forwards commands onto the app's main actor.
final class CommandServer: @unchecked Sendable {
    private var listener: Int32 = -1
    private var lock: Int32 = -1

    func start(handle: @escaping @MainActor @Sendable (Request) async -> Response) throws {
        try LocalSocket.prepareDirectory()
        lock = Darwin.open(LocalSocket.directory + "/instance.lock", O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            throw ServiceError("Shelferry is already running.")
        }
        listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0 else { throw LocalSocket.failure("Create listener") }
        unlink(LocalSocket.path)
        var address = try LocalSocket.address()
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, listen(listener, 16) == 0 else { throw LocalSocket.failure("Listen") }
        chmod(LocalSocket.path, 0o600)
        DispatchQueue(label: "us.tahsin.shelferry.commands").async { [self] in
            while true {
                let client = accept(listener, nil, nil)
                if client < 0 { if errno == EINTR { continue }; break }
                LocalSocket.configure(client)
                var uid: uid_t = 0; var gid: gid_t = 0
                guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { Darwin.close(client); continue }
                do {
                    let request = try LocalSocket.receive(Request.self, from: client)
                    let done = DispatchSemaphore(value: 0)
                    Task { @MainActor in
                        let response = await handle(request)
                        try? LocalSocket.send(response, to: client)
                        Darwin.close(client)
                        done.signal()
                    }
                    done.wait()
                } catch {
                    try? LocalSocket.send(Response(error: error.localizedDescription), to: client)
                    Darwin.close(client)
                }
            }
        }
    }
}
