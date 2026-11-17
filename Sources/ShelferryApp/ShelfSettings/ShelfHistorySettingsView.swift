import SwiftUI

struct ShelfHistorySettingsView: View {
    @Bindable var model: ShelfSettingsModel

    var body: some View {
        Section("Connected storage") {
            LabeledContent("Connected files and history", value: model.shelf.connection.storedBytes.formatted(.byteCount(style: .file)))
            if model.draft.isConnected {
                TextField("Shelf limit (GB)", text: $model.limitGB, prompt: Text("1"))
                Text("Includes stored files, manually added copies, and older versions. Imports stop at the limit; existing files are kept. Temporary refresh data may require extra disk space.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section("Older file versions") {
            if model.shelf.connection.versions.isEmpty {
                Text("Changed files appear here after a Collect refresh. Unchanged files do not create versions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.shelf.connection.versions) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(version.path).lineLimit(2).truncationMode(.middle)
                            Text(version.date, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Export…") { model.export(version) }
                    }
                }
                Button("Delete All Older Versions…", role: .destructive) { model.confirmsHistoryRemoval = true }
                    .disabled(model.shelf.connection.isRefreshing)
            }
        }
    }
}
