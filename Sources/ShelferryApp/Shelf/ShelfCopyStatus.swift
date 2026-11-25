import SwiftUI

/// Keeps the footer still while confirmation gently replaces the selection summary.
struct ShelfCopyStatus: View {
    let summary: String
    let copiedCount: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .leading) {
            if let copiedCount {
                Label(copiedCount == 1 ? "Copied 1 item" : "Copied \(copiedCount) items", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(reduceMotion ? .opacity : .offset(y: 5).combined(with: .opacity))
            } else {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .font(.caption)
        .lineLimit(1)
        .animation(.easeOut(duration: 0.2), value: copiedCount)
    }
}
