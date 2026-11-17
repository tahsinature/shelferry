import AppKit

@MainActor
enum ShelfDeleteDialog {
    enum Choice { case hide, delete, cancel }

    static func choose(for shelf: Shelf) -> Choice {
        let alert = NSAlert()
        alert.messageText = "Delete “\(shelf.name)”?"
        alert.informativeText = "Delete removes this shelf, its stored copies, and its version history. Original files stay where they are. Hide keeps the shelf and everything on it."
        alert.addButton(withTitle: "Hide")
        alert.addButton(withTitle: "Delete").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .hide
        case .alertSecondButtonReturn: return .delete
        default: return .cancel
        }
    }
}
