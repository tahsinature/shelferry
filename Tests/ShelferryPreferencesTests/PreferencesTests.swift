import Foundation
import Testing
@testable import ShelferryApp

@MainActor
struct PreferencesTests {
    @Test func partialConfigUsesDefaults() throws {
        let value = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
        #expect(value.shiftDragOpens)
        #expect(!value.removeAfterDragOut)
        #expect(value.shortcuts.isEmpty)
    }

    @Test func rejectsInvalidAndDuplicateHotkeys() {
        var value = Preferences()
        value.shortcuts = ["toggle": "ctrl+opt+s", "manager": "control+alt+s"]
        #expect(throws: (any Error).self) { try value.validate() }
        value.shortcuts = ["unknown": "ctrl+opt+s"]
        #expect(throws: (any Error).self) { try value.validate() }
        value.shortcuts = ["toggle": "cmd+q"]
        #expect(throws: (any Error).self) { try value.validate() }
    }

    @Test func preservesSymlinkAndLastValidConfiguration() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appending(path: "managed.json")
        let link = folder.appending(path: "config.json")
        try Data("{}".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let store = PreferencesStore(configFile: link)
        store.update { $0.shiftDragOpens = false }
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == target.path)
        #expect(!store.value.shiftDragOpens)
        let valid = try Data(contentsOf: target)
        try Data("broken".utf8).write(to: target, options: .atomic)
        store.reload()
        #expect(store.error != nil)
        #expect(!store.value.shiftDragOpens)
        store.update { $0.shiftDragOpens = true }
        #expect(try String(contentsOf: target, encoding: .utf8) == "broken")
        try valid.write(to: target, options: .atomic)
        store.reload()
        #expect(store.error == nil)
        var changed = Preferences(); changed.shiftDragOpens = true
        try JSONEncoder().encode(changed).write(to: target, options: .atomic)
        store.reload()
        #expect(store.value.shiftDragOpens)
    }
}
