import SwiftUI

struct ShelfSizeLabel: View {
    let shelf: Shelf
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(shelf.receivingIDs.isEmpty
             ? shelf.totalBytes.formatted(.byteCount(style: .file))
             : "Receiving…")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .contentTransition(.numericText(value: Double(shelf.totalBytes)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: shelf.totalBytes)
            .help("Total file size. Folder contents are not included.")
            .accessibilityLabel("Shelf size")
            .accessibilityValue(shelf.receivingIDs.isEmpty
                                ? shelf.totalBytes.formatted(.byteCount(style: .file)) : "Receiving files")
    }
}
