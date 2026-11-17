import Foundation
import Observation
import ShelferryCore
import ShelferryProtocol

struct Preferences: Codable, Equatable {
    var shiftDragOpens = true
    var removeAfterDragOut = false
    var shortcuts: [String: String] = [:]

    init() {}
    enum CodingKeys: String, CodingKey { case shiftDragOpens, removeAfterDragOut, shortcuts }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shiftDragOpens = try values.decodeIfPresent(Bool.self, forKey: .shiftDragOpens) ?? true
        removeAfterDragOut = try values.decodeIfPresent(Bool.self, forKey: .removeAfterDragOut) ?? false
        shortcuts = try values.decodeIfPresent([String: String].self, forKey: .shortcuts) ?? [:]
    }

    func validate() throws {
        var used = Set<KeyCombo>()
        for (action, keys) in shortcuts {
            guard GlobalShelfAction(rawValue: action) != nil, let combo = KeyCombo(keys) else {
                throw ServiceError("Invalid shortcut: \(action) = \(keys)")
            }
            guard !combo.isReservedBySystem else { throw ServiceError("\(keys) is reserved for everyday macOS actions.") }
            guard used.insert(combo).inserted else { throw ServiceError("Each action needs a different shortcut.") }
        }
    }
}

enum GlobalShelfAction: String, CaseIterable, Identifiable {
    case toggle, newShelf, manager
    var id: String { rawValue }
    var title: String {
        switch self { case .toggle: "Show / Hide Shelves"; case .newShelf: "New Shelf"; case .manager: "Shelf Manager" }
    }
}

@MainActor @Observable
final class PreferencesStore {
    private(set) var value = Preferences()
    private(set) var error: String?
    let file: URL
    @ObservationIgnored var onChange: (Preferences) -> Void = { _ in }
    @ObservationIgnored private var lastData: Data?
    @ObservationIgnored private var invalidFile = false
    @ObservationIgnored private var timer: Timer?

    init(configFile: URL? = nil) {
        let path = ProcessInfo.processInfo.environment["SHELFERRY_CONFIG_DIR"] ?? "~/.config/shelferry"
        file = configFile ?? URL(fileURLWithPath: (path as NSString).expandingTildeInPath).appending(path: "config.json")
        if !FileManager.default.fileExists(atPath: file.path) {
            // Import the preview's two preferences once, without touching Tooki defaults.
            value.shiftDragOpens = UserDefaults.standard.object(forKey: "shiftDragOpens") as? Bool ?? true
            value.removeAfterDragOut = UserDefaults.standard.bool(forKey: "removeAfterDragOut")
            do { try write(value) } catch { self.error = error.localizedDescription }
        }
        reload()
        // Poll the file contents, not its inode: atomic saves and symlink target edits both work.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func update(_ change: (inout Preferences) -> Void) {
        var updated = value
        change(&updated)
        do {
            // Reload external edits first instead of silently overwriting a newer file.
            let disk = try Data(contentsOf: file)
            guard disk == lastData else {
                reload()
                throw ServiceError("Settings changed on disk. Please retry your change.")
            }
            try updated.validate()
            try write(updated)
            value = updated; error = nil; onChange(updated)
        } catch { self.error = error.localizedDescription }
    }

    func reload() {
        do {
            let data = try Data(contentsOf: file)
            guard data != lastData else {
                if invalidFile { error = nil; invalidFile = false }
                return
            }
            let updated = try JSONDecoder().decode(Preferences.self, from: data)
            try updated.validate()
            value = updated; lastData = data; error = nil; invalidFile = false; onChange(updated)
        } catch { invalidFile = true; self.error = "Could not read config.json: \(error.localizedDescription). Last valid settings are still active." }
    }

    private func write(_ preferences: Preferences) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preferences)
        try JSONFile.write(data, to: file)
        lastData = data
    }
}
