import Foundation

public struct Request: Codable, Sendable {
    public var version = 1
    public var command: String
    public var shelf: String?
    public var name: String?
    public var paths: [String]
    public var copy: Bool
    public var confirmed: Bool

    public init(command: String, shelf: String? = nil, name: String? = nil,
                paths: [String] = [], copy: Bool = false, confirmed: Bool = false) {
        self.command = command; self.shelf = shelf; self.name = name
        self.paths = paths; self.copy = copy; self.confirmed = confirmed
    }
}

public struct ShelfRecord: Codable, Sendable {
    public let id: String
    public let name: String
    public let count: Int
    public init(id: String, name: String, count: Int) {
        self.id = id; self.name = name; self.count = count
    }
}

public struct ItemRecord: Codable, Sendable {
    public let id: String
    public let path: String
    public let isCopy: Bool
    public init(id: String, path: String, isCopy: Bool) {
        self.id = id; self.path = path; self.isCopy = isCopy
    }
}

public struct Response: Codable, Sendable {
    public var version = 1
    public var error: String?
    public var shelves: [ShelfRecord] = []
    public var items: [ItemRecord] = []
    public init(error: String? = nil, shelves: [ShelfRecord] = [], items: [ItemRecord] = []) {
        self.error = error; self.shelves = shelves; self.items = items
    }
}

public struct ServiceError: Error, LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
