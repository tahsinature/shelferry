import SwiftUI

struct ShelfConnectionStatusView: View {
    let shelf: Shelf

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: shelf.connectionSettings.source == .folder ? "folder.badge.gearshape" : "network")
                    .foregroundStyle(.secondary)
                if shelf.connection.isRefreshing {
                    ProgressView().controlSize(.mini)
                    Text("Refreshing…")
                } else if shelf.connectionSettings.paused {
                    Text("Paused")
                } else if shelf.connection.error != nil {
                    Text("Needs attention").foregroundStyle(.orange)
                } else if let date = shelf.connection.lastRefresh {
                    Text("Updated \(date, style: .relative) ago").lineLimit(1)
                } else { Text("Not refreshed yet") }
                Spacer(minLength: 0)
                Button("Refresh now", systemImage: "arrow.clockwise", action: shelf.connection.refresh)
                    .labelStyle(.iconOnly).help("Refresh now").disabled(shelf.connection.isRefreshing)
                Button(shelf.connectionSettings.paused ? "Resume" : "Pause",
                       systemImage: shelf.connectionSettings.paused ? "play.fill" : "pause.fill",
                       action: shelf.connection.togglePause)
                    .labelStyle(.iconOnly).help(shelf.connectionSettings.paused ? "Resume" : "Pause")
            }
            if let error = shelf.connection.error {
                Text(error).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Shelf Settings…", action: shelf.settingsWindow.show)
            }
        }
        .font(.caption)
        .buttonStyle(.borderless)
        .padding(.horizontal, 12).padding(.vertical, 8)
        Divider()
    }
}
