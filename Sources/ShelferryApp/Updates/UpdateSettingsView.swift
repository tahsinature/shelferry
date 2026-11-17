import SwiftUI

struct UpdateSettingsView: View {
    let updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Software Updates").font(.headline)
            if updater.isEnabled {
                Text(statusText).fixedSize(horizontal: false, vertical: true)
                if let date = updater.lastChecked {
                    Text("Last checked \(date, format: .relative(presentation: .named))")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updater.checksAutomatically },
                    set: { updater.setChecksAutomatically($0) }
                ))
                Button("Check for Updates…", action: updater.check)
                    .disabled(!updater.canCheck)
                Text("Shelferry verifies downloaded updates before installing them.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Updates are off in development builds.").foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch updater.state {
        case .idle: "Keep Shelferry up to date."
        case .checking: "Checking for updates…"
        case .upToDate: "Shelferry is up to date."
        case .available(let version): "Version \(version) is available."
        case .failed(let message): message
        }
    }
}
