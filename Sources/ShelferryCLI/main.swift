import Foundation
import Darwin
import ShelferryProtocol

let help = """
Shelferry — a native floating file shelf

  shelferry list [--json]
  shelferry items --shelf <id or name> [--json | --null]
  shelferry new [--name <name>]
  shelferry add [--shelf <id or name | new>] [--copy | --original] -- <paths...>
  shelferry show|hide|toggle [--shelf <id or name>]
  shelferry manager
  shelferry rename --shelf <id or name> --name <name>
  shelferry clear|delete --shelf <id or name> --yes

Originals stay at their existing paths. --copy creates Shelferry-owned copies.
clear empties a shelf; delete removes it. Both delete owned copies, never originals.
The app starts automatically. SHELFERRY_APP can point to a development .app bundle.
"""
let raw = Array(CommandLine.arguments.dropFirst())
if raw.isEmpty || raw == ["--help"] || raw == ["-h"] { print(help); exit(0) }
if raw == ["--version"] {
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let bundle = Bundle(url: executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
    print(bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")
    exit(0)
}
do {
    let arguments = try Arguments(raw)
    let fd: Int32
    if let existing = try? LocalSocket.connect() { fd = existing }
    else {
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        if let app = ProcessInfo.processInfo.environment["SHELFERRY_APP"] {
            launcher.arguments = ["-g", app]
        } else { launcher.arguments = ["-g", "-b", "us.tahsin.shelferry"] }
        launcher.standardOutput = FileHandle.nullDevice
        try launcher.run(); launcher.waitUntilExit()
        guard launcher.terminationStatus == 0 else { throw ServiceError("Install Shelferry.app in Applications, or set SHELFERRY_APP.") }
        var connected: Int32?
        for _ in 0..<100 {
            if let candidate = try? LocalSocket.connect() { connected = candidate; break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard let connected else { throw ServiceError("Shelferry did not become ready within 10 seconds.") }
        fd = connected
    }
    defer { Darwin.close(fd) }
    try LocalSocket.send(arguments.request, to: fd)
    let response = try LocalSocket.receive(Response.self, from: fd)
    if arguments.json {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        FileHandle.standardOutput.write(try encoder.encode(response)); print("")
    }
    if let error = response.error { throw ServiceError(error) }
    if !arguments.json {
        for shelf in response.shelves { print("\(shelf.id)\t\(shelf.name)\t\(shelf.count)") }
        for item in response.items {
            FileHandle.standardOutput.write(Data((item.path + (arguments.nul ? "\0" : "\n")).utf8))
        }
    }
} catch {
    FileHandle.standardError.write(Data("shelferry: \(error.localizedDescription)\n".utf8)); exit(1)
}
