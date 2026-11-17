import SwiftUI

struct ShelfSourceSettingsView: View {
    @Bindable var model: ShelfSettingsModel

    var body: some View {
        Section("Shelf source") {
            Picker("Source", selection: $model.draft.source) {
                ForEach(ShelfConnectionSettings.Source.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if model.draft.source == .regular {
                Text("Add files by dropping or pasting them onto the shelf.").foregroundStyle(.secondary)
            } else if model.draft.source == .folder {
                TextField("Folder", text: $model.draft.location, prompt: Text("Choose a folder"))
                Button("Choose Folder…", action: model.chooseFolder)
            } else {
                TextField("URL", text: $model.draft.location, prompt: Text("https://example.com/download"))
                    .autocorrectionDisabled()
                Text("Watches a downloadable file or ZIP. JSON directory listings need a source adapter and are not interpreted as folders.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if model.draft.source == .remote {
            Section("Request headers") {
                TextField("Header: value", text: $model.headers, axis: .vertical)
                    .lineLimit(3...8).font(.system(.body, design: .monospaced)).autocorrectionDisabled()
                Text("Saved in macOS Keychain. Use Authorization: Bearer … for token authentication.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Import a cURL request") {
                TextField("curl 'https://…' -H 'Authorization: …'", text: $model.curl, axis: .vertical)
                    .lineLimit(2...4).font(.system(.body, design: .monospaced)).autocorrectionDisabled()
                Button("Import Request", action: model.importCurl).disabled(model.curl.isEmpty)
                Text("GET requests only. The command is parsed, never executed.").font(.caption).foregroundStyle(.secondary)
            }
        }
        if model.draft.isConnected {
            Section {
                Button(model.isTesting ? "Testing…" : "Test Connection", action: model.test).disabled(model.isTesting)
                Text("Tests read the source and archive contents without changing this shelf.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
