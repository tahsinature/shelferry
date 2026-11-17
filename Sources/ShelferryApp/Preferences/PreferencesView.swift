import AppKit
import SwiftUI
import ShelferryCore

struct PreferencesView: View {
    let pane: PreferencesPane
    let store: PreferencesStore
    let hotkeys: GlobalHotkeys
    let updater: Updater
    private let buildInfo = BuildInfo()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch pane {
            case .general: general
            case .hotkeys: shortcuts
            case .updates: UpdateSettingsView(updater: updater)
            case .about: about
            }
            if let error = store.error ?? hotkeys.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 490, height: 360, alignment: .topLeading)
    }

    private var general: some View {
        Form {
            Section {
                Toggle("Keep shelves on top", isOn: binding(\.keepShelvesOnTop))
                Toggle("Show shelves when Shift-dragging", isOn: binding(\.shiftDragOpens))
                Toggle("Remove items after dragging them out", isOn: binding(\.removeAfterDragOut))
                Text("Cancelled drags keep their items. Original files remain at their destination.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configuration")
                        Text("~/.config/shelferry/config.json").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.file]) }
                }
                Text("Changes save automatically. Editing the file updates Shelferry too.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Global Hotkeys").font(.headline)
            Text("Use these shortcuts from any app. Leave an action unassigned if another launcher handles it.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(GlobalShelfAction.allCases) { action in
                HStack {
                    Text(action.title)
                    Spacer()
                    HotkeyRecorder(combo: store.value.shortcuts[action.rawValue].flatMap(KeyCombo.init), validate: { combo in
                        if combo.isReservedBySystem { return "This shortcut is reserved for everyday macOS actions." }
                        if store.value.shortcuts.contains(where: { $0.key != action.rawValue && KeyCombo($0.value) == combo }) {
                            return "Another Shelferry action already uses that shortcut."
                        }
                        return nil
                    }, onRecordingChange: { recording in
                        if recording { hotkeys.suspend() } else { hotkeys.resume(store.value.shortcuts) }
                    }, onChange: { combo in
                        store.update { $0.shortcuts[action.rawValue] = combo?.description }
                    })
                }
                if action != GlobalShelfAction.allCases.last { Divider() }
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Shelferry").font(.title.bold())
                    Text("Version \(version)").foregroundStyle(.secondary)
                    Text("\(buildInfo.channel) · \(buildInfo.exactDate)")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Text("A native floating shelf for carrying files between apps.")
            VStack(alignment: .leading, spacing: 14) {
                Link(destination: URL(string: "https://github.com/tahsinature/shelferry/blob/master/docs/USAGE.md")!) { Label("Help & CLI guide", systemImage: "questionmark.circle") }
                Link(destination: URL(string: "https://github.com/tahsinature/shelferry")!) { Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right") }
                Link(destination: URL(string: "https://github.com/tahsinature/shelferry/issues")!) { Label("Report an issue", systemImage: "bubble.left.and.exclamationmark.bubble.right") }
            }
            Text("© 2026 Tahsin · MIT License").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "development") (\(info["CFBundleVersion"] as? String ?? "1"))"
    }
    private func binding(_ keyPath: WritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
        Binding(get: { store.value[keyPath: keyPath] }, set: { value in store.update { $0[keyPath: keyPath] = value } })
    }
}
