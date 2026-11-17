import Foundation

public struct ShelfConfig: Codable, Equatable, Sendable {
    public var enabled = true
    /// Holding Shift while dragging something shows the shelf next to the pointer.
    public var shiftDragOpens = true
    /// Optional cleanup after any accepted drop. Off by default because file pickers also accept navigation drops.
    public var removeAfterDragOut = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ShelfConfig()
        enabled = try container.decode(.enabled, default: defaults.enabled)
        shiftDragOpens = try container.decode(.shiftDragOpens, default: defaults.shiftDragOpens)
        removeAfterDragOut = try container.decode(.removeAfterDragOut, default: defaults.removeAfterDragOut)
    }
}

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? defaultValue
    }
}
