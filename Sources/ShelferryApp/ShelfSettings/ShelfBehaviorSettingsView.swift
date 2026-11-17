import SwiftUI

struct ShelfBehaviorSettingsView: View {
    @Bindable var model: ShelfSettingsModel

    var body: some View {
        if model.draft.isConnected {
            Section("Sync behavior") {
                Picker("Mode", selection: $model.draft.mode) {
                    ForEach(ShelfConnectionSettings.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Text(model.draft.mode == .mirror
                     ? "Matches the source, including deletions. Manual additions are disabled."
                     : "Keeps collected files when the source removes them. Changed files get individual versions. Manual additions are allowed.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("File storage") {
                if model.draft.source == .folder && model.draft.mode == .mirror {
                    Picker("Store as", selection: $model.draft.storage) {
                        ForEach(ShelfConnectionSettings.Storage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } else { LabeledContent("Store as", value: "Copy") }
                Text(model.draft.usesReferences
                     ? "References use the original files. Editing or moving them affects the source. Folder references show all contents; filters apply only to top-level items."
                     : "Shelferry stores its own copies. Original files stay at their source.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Treat ZIP archives as folders", isOn: $model.draft.archivesAsFolders)
                    .disabled(model.draft.usesReferences)
                Text("Top-level ZIP files become folders, keeping their .zip names. Files inside get their own versions. Nested ZIPs stay unopened.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("Choose a Folder or Remote source to configure sync behavior.").foregroundStyle(.secondary)
        }
    }
}
