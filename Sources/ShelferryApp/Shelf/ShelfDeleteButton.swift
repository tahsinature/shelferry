import AppKit
import ShelferryDesignSystem
import SwiftUI

struct ShelfDeleteButton: View {
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var isOptionPressed = false
    @State private var modifierMonitor: Any?

    private var isImmediateDelete: Bool { isHovered && isOptionPressed }

    var body: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isImmediateDelete ? Color.white : Color.primary)
                .frame(width: 22, height: 22)
                .background(isImmediateDelete ? Color.red : Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(InteractionButtonStyle(radius: 11))
        .accessibilityLabel("Delete shelf")
        .help(isOptionPressed ? "Delete immediately" : "Delete shelf… (Option-click to delete immediately)")
        .onHover(perform: updateHover)
        .onDisappear(perform: stopMonitoringModifiers)
    }

    private func updateHover(_ hovering: Bool) {
        isHovered = hovering
        stopMonitoringModifiers()
        isOptionPressed = NSEvent.modifierFlags.contains(.option)
        guard hovering else { return }
        modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            MainActor.assumeIsolated {
                isOptionPressed = event.modifierFlags.contains(.option)
            }
            return event
        }
    }

    private func stopMonitoringModifiers() {
        if let modifierMonitor { NSEvent.removeMonitor(modifierMonitor) }
        modifierMonitor = nil
    }
}
