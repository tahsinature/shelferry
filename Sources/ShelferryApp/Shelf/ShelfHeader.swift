import ShelferryDesignSystem
import AppKit
import SwiftUI

/// The shelf's top bar, the same in every view: the name (drag it to move the shelf),
/// Stack or List, the ⋯ menu, and a permanent Delete button.
/// An empty shelf leaves out what needs items: the view switch and the item commands.
struct ShelfHeader: View {
    let shelf: Shelf
    let onDelete: () -> Void
    let onClear: () -> Void

    static let height: CGFloat = 42

    @State private var isRenaming = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 0) {
                ShelfTitle(shelf: shelf, isEditing: $isRenaming)
                Spacer(minLength: 4)
                if !shelf.isEmpty {
                    ShelfSizeLabel(shelf: shelf)
                        .padding(.trailing, 6)
                }
            }
            .padding(.leading, 12)
            .frame(maxHeight: .infinity)
            .shelfWindowDragArea()
            if !shelf.isEmpty { ShelfViewSwitch(shelf: shelf).disabled(shelf.isShowingConversion) }
            ShelfMoreMenu(shelf: shelf, onRename: { isRenaming = true }, onClear: onClear, onDelete: onDelete)
                .disabled(shelf.isShowingConversion)
            ShelfDeleteButton(onDelete: onDelete)
        }
        .padding(.trailing, 12)
        .frame(height: Self.height)
    }
}

/// Two icons that show, and switch, how the shelf is shown: a stack or a list.
private struct ShelfViewSwitch: View {
    let shelf: Shelf

    var body: some View {
        HStack(spacing: 2) {
            option(symbol: "square.stack", help: "Show as a stack", isList: false)
            option(symbol: "list.bullet", help: "Show as a list", isList: true)
        }
        .padding(2)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }

    private func option(symbol: String, help: String, isList: Bool) -> some View {
        let isOn = shelf.isExpanded == isList
        return Button { shelf.isExpanded = isList } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isOn ? .primary : .secondary)
                .frame(width: 24, height: 18)
                .background(isOn ? Color.primary.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(InteractionButtonStyle(radius: 5))
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Everything you can do with the whole shelf.
private struct ShelfMoreMenu: View {
    let shelf: Shelf
    let onRename: () -> Void
    let onClear: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button("Shelf Settings…", action: shelf.settingsWindow.show)
                .keyboardShortcut(",", modifiers: [.command, .shift])
            if shelf.connectionSettings.isConnected {
                Button("Refresh Now", action: shelf.connection.refresh).disabled(shelf.connection.isRefreshing)
                Button(shelf.connectionSettings.paused ? "Resume" : "Pause", action: shelf.connection.togglePause)
            }
            Divider()
            Button("Rename", action: onRename)
            if !shelf.isEmpty {
                Button("Show All in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(shelf.readyURLs)
                }
                Button("Copy All Paths") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shelf.readyURLs.map(\.path).joined(separator: "\n"), forType: .string)
                }
            }
            Divider()
            if shelf.items.contains(where: shelf.canEdit) { Button("Clear", action: onClear) }
            Button("Delete Shelf", role: .destructive, action: onDelete)
                .keyboardShortcut(.delete, modifiers: .command)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(InteractionButtonStyle(radius: 11))
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Shelf actions")
        .accessibilityLabel("Shelf actions")
    }
}

extension View {
    /// Empty space that moves the shelf when dragged, with an open hand to say so.
    func shelfWindowDragArea() -> some View {
        modifier(ShelfWindowDragArea())
    }
}

private struct ShelfWindowDragArea: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(WindowDragView())
            .onHover { hovering in
                guard hovering != isHovered else { return }
                isHovered = hovering
                hovering ? NSCursor.openHand.push() : NSCursor.pop()
            }
            .onDisappear {
                if isHovered { NSCursor.pop() }
                isHovered = false
            }
    }

    private struct WindowDragView: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView { DragView() }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            window?.performDrag(with: event)
            NSCursor.pop()
        }
    }
}
