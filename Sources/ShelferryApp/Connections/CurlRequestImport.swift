import Foundation

/// Imports a small, explicit subset of cURL syntax. It never invokes a shell.
enum CurlRequestImport {
    static func parse(_ command: String) throws -> (url: String, headers: String) {
        let words = try tokenize(command)
        guard words.first == "curl" else { throw ConnectionError("Paste a command beginning with curl.") }
        var url: String?
        var headers: [String] = []
        var index = 1
        while index < words.count {
            let word = words[index]
            switch word {
            case "-H", "--header", "--url", "-u", "--user", "-X", "--request":
                index += 1
                guard index < words.count else { throw ConnectionError("Missing value after \(word).") }
                let value = words[index]
                if ["-H", "--header"].contains(word) { headers.append(value) }
                else if word == "--url" { url = value }
                else if ["-u", "--user"].contains(word) {
                    guard value.contains(":") else { throw ConnectionError("Basic authentication needs user:password.") }
                    headers.append("Authorization: Basic " + Data(value.utf8).base64EncodedString())
                } else if value.uppercased() != "GET" { throw ConnectionError("Connected shelves currently support GET requests only.") }
            case "-L", "--location", "-s", "--silent", "-S", "--show-error", "--compressed", "--globoff": break
            default:
                guard !word.hasPrefix("-"), url == nil else {
                    throw ConnectionError("Unsupported cURL option: \(word). Use a URL and request headers for a GET request.")
                }
                url = word
            }
            index += 1
        }
        guard let url else { throw ConnectionError("The cURL command has no URL.") }
        let text = headers.joined(separator: "\n")
        _ = try ConnectionCredentials.headers(text)
        return (url, text)
    }

    private static func tokenize(_ command: String) throws -> [String] {
        var result: [String] = []
        var token = ""
        var quote: Character?
        var escaped = false
        for character in command {
            if escaped { if character != "\n" { token.append(character) }; escaped = false; continue }
            if character == "\\", quote != "'" { escaped = true; continue }
            if let current = quote {
                if character == current { quote = nil } else { token.append(character) }
            } else if character == "'" || character == "\"" { quote = character }
            else if character.isWhitespace {
                if !token.isEmpty { result.append(token); token = "" }
            } else if "|;&<>`".contains(character) {
                throw ConnectionError("Shell operators are not supported. Paste one curl request.")
            } else { token.append(character) }
        }
        guard quote == nil, !escaped else { throw ConnectionError("The cURL command has an unfinished quote or escape.") }
        if !token.isEmpty { result.append(token) }
        return result
    }
}
