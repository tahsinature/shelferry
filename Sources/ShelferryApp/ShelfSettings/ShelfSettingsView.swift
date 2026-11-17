import SwiftUI

struct ShelfSettingsView: View {
    @Bindable var model: ShelfSettingsModel
    @State private var pane = "Source"
    private let panes = ["Source", "Behavior", "Refresh & Filters", "Storage & History"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings section", selection: $pane) {
                ForEach(panes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()
            Form {
                switch pane {
                case "Source": ShelfSourceSettingsView(model: model)
                case "Behavior": ShelfBehaviorSettingsView(model: model)
                case "Refresh & Filters": ShelfRefreshSettingsView(model: model)
                default: ShelfHistorySettingsView(model: model)
                }
            }
            .formStyle(.grouped)
            Spacer(minLength: 0)
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).font(.callout).padding(.horizontal).padding(.bottom, 10)
                    .textSelection(.enabled)
            } else if let result = model.testResult {
                Text(result).font(.callout).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom, 10)
            }
            Divider()
            HStack {
                if model.shelf.connection.isRefreshing {
                    ProgressView().controlSize(.small)
                    Text("Refreshing shelf…").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Apply", action: model.requestApply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isTesting || model.shelf.connection.isRefreshing)
            }
            .padding()
        }
        .alert("Apply shelf settings?", isPresented: $model.needsConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Apply", action: model.apply)
        } message: { Text(model.changeSummary) }
        .alert("Delete older versions?", isPresented: $model.confirmsHistoryRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Versions", role: .destructive, action: model.clearHistory)
        } message: { Text("Current files stay on the shelf. Deleted versions cannot be recovered.") }
    }
}
