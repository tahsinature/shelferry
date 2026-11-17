import ShelferryDesignSystem
import SwiftUI

struct ShelfDeleteButton: View {
    let onDelete: () -> Void

    var body: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(InteractionButtonStyle(radius: 11))
        .accessibilityLabel("Delete shelf")
        .help("Delete shelf…")
    }
}
