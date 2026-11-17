import SwiftUI

struct ShelfRefreshSettingsView: View {
    @Bindable var model: ShelfSettingsModel

    var body: some View {
        if model.draft.isConnected {
            Section("Automatic refresh") {
                Toggle("Refresh automatically", isOn: $model.draft.automaticRefresh)
                TextField("Interval in seconds", value: $model.draft.refreshSeconds, format: .number)
                    .disabled(!model.draft.automaticRefresh)
                Text("Checks for changes every 5 seconds to 24 hours while Shelferry is running. Refresh now remains available when paused.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Filters") {
                Toggle("Include hidden files", isOn: $model.draft.includeHidden)
                TextField("Include patterns", text: $model.draft.includePatterns, axis: .vertical).lineLimit(2...5)
                TextField("Exclude patterns", text: $model.draft.excludePatterns, axis: .vertical).lineLimit(2...5)
                Text("One pattern per line, such as *.png or cache/*. Leave Include blank for all files. Excluding a folder excludes its contents. Collect keeps files already imported.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("Regular shelves do not refresh automatically.").foregroundStyle(.secondary)
        }
    }
}
