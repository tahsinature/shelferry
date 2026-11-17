import Foundation
import Network
import Testing
@testable import ShelferryApp

struct RemoteConnectionTests {
    @Test func authenticatedDownloadAndHTTPFailure() async throws {
        let server = try ConnectionHTTPFixture()
        let port = try await server.start()
        defer { server.stop() }
        var settings = ShelfConnectionSettings()
        settings.source = .remote
        settings.location = "http://127.0.0.1:\(port)/file"
        let source = try await ConnectionSource.load(settings, headers: ["Authorization": "Bearer fixture"])
        defer { if let temporary = source.temporary { try? FileManager.default.removeItem(at: temporary) } }
        let file = source.root.appending(path: "example.txt")
        #expect(try String(contentsOf: file, encoding: .utf8) == "remote content")
        await #expect(throws: (any Error).self) { try await ConnectionSource.load(settings, headers: [:]) }
    }

    @Test func downloadLimitAndCrossOriginRedirectAreRejected() async throws {
        let server = try ConnectionHTTPFixture()
        let port = try await server.start()
        defer { server.stop() }
        var settings = ShelfConnectionSettings()
        settings.source = .remote
        settings.location = "http://127.0.0.1:\(port)/file"
        settings.limitBytes = 3
        await #expect(throws: (any Error).self) {
            try await ConnectionSource.load(settings, headers: ["Authorization": "Bearer fixture"])
        }
        settings.location = "http://127.0.0.1:\(port)/redirect"
        settings.limitBytes = 1000
        await #expect(throws: (any Error).self) {
            try await ConnectionSource.load(settings, headers: ["Authorization": "Bearer fixture"])
        }
    }
}

private final class ConnectionHTTPFixture: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "Shelferry.ConnectionHTTPFixture")

    init() throws { listener = try NWListener(using: .tcp, on: .any) }

    func start() async throws -> UInt16 {
        listener.newConnectionHandler = { [queue] connection in
            connection.start(queue: queue)
            Self.receive(connection, previous: Data())
        }
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: listener.port!.rawValue)
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() { listener.cancel() }

    private static func receive(_ connection: NWConnection, previous: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, complete, error in
            let bytes = previous + (data ?? Data())
            guard error == nil, bytes.count < 65_536 else { connection.cancel(); return }
            let request = String(decoding: bytes, as: UTF8.self)
            guard request.contains("\r\n\r\n") else {
                if complete { connection.cancel() } else { receive(connection, previous: bytes) }
                return
            }
            let response: String
            if request.hasPrefix("GET /redirect ") {
                response = "HTTP/1.1 302 Found\r\nLocation: https://example.invalid/secret\r\nContent-Length: 0\r\n\r\n"
            } else if request.lowercased().contains("authorization: bearer fixture") {
                response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nX-Filename: example.txt\r\nContent-Length: 14\r\nConnection: close\r\n\r\nremote content"
            } else {
                response = "HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            }
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
