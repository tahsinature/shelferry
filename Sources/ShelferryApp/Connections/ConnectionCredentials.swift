import Foundation
import Security

enum ConnectionCredentials {
    private static let service = "us.tahsin.shelferry.connections"

    static func read(_ id: String?) throws -> String {
        guard let id else { return "" }
        var query = query(id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data,
              let text = String(data: data, encoding: .utf8) else {
            throw ConnectionError("Could not read request headers from Keychain (\(status)).")
        }
        return text
    }

    static func write(_ text: String, id: String) throws {
        let attributes = [kSecValueData as String: Data(text.utf8)]
        var status = SecItemUpdate(query(id) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(id).merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw ConnectionError("Could not save request headers in Keychain (\(status)).") }
    }

    static func delete(_ id: String?) {
        guard let id else { return }
        SecItemDelete(query(id) as CFDictionary)
    }

    static func headers(_ text: String) throws -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw ConnectionError("Use one Header: value per line.") }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-.^_`|~")
            guard !name.isEmpty, name.unicodeScalars.allSatisfy(allowed.contains), !value.contains("\r"),
                  !["host", "content-length", "connection"].contains(name.lowercased()) else {
                throw ConnectionError("Invalid or unsupported request header: \(name).")
            }
            result[name] = value
        }
        return result
    }

    private static func query(_ id: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id]
    }
}
