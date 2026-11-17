import Foundation

public struct Arguments {
    public let request: Request
    public let json: Bool
    public let nul: Bool
    public init(_ args: [String]) throws {
        guard let command = args.first, ["list", "items", "new", "add", "show", "hide", "toggle", "rename", "clear", "delete", "manager", "settings", "ping"].contains(command) else {
            throw ServiceError("Unknown command. Run shelferry --help.")
        }
        var request = Request(command: command)
        var json = false; var nul = false; var positional = false; var index = 1
        while index < args.count {
            let arg = args[index]
            if positional { request.paths.append(arg) }
            else {
                switch arg {
                case "--": positional = true
                case "--json": json = true
                case "--null": nul = true
                case "--copy": request.copy = true
                case "--original": request.copy = false
                case "--yes": request.confirmed = true
                case "--shelf", "-s", "--name":
                    index += 1
                    guard index < args.count, !args[index].isEmpty else { throw ServiceError("\(arg) requires a value.") }
                    if arg == "--name" { request.name = args[index] } else { request.shelf = args[index] }
                default:
                    guard !arg.hasPrefix("-") else { throw ServiceError("Unknown option: \(arg)") }
                    request.paths.append(arg)
                }
            }
            index += 1
        }
        if command == "items", request.shelf == nil, request.paths.count == 1 {
            request.shelf = request.paths.removeFirst()
        }
        guard command == "add" || request.paths.isEmpty else { throw ServiceError("Unexpected positional arguments.") }
        if command == "add" {
            guard !request.paths.isEmpty else { throw ServiceError("Provide at least one file or folder.") }
            request.paths = request.paths.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath).standardizedFileURL.path }
        }
        if ["items", "rename", "clear", "delete"].contains(command), request.shelf == nil {
            throw ServiceError("\(command) requires --shelf <id or name>.")
        }
        if command == "rename", request.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            throw ServiceError("rename requires --name <name>.")
        }
        if ["clear", "delete"].contains(command), !request.confirmed {
            throw ServiceError("This deletes Shelferry-owned copies. Originals stay untouched. Pass --yes to confirm.")
        }
        guard !(json && nul), !nul || command == "items" else { throw ServiceError("--null is only supported by items, without --json.") }
        self.request = request; self.json = json; self.nul = nul
    }
}
