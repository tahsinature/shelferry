import AppKit

@MainActor
enum ShelfDeleteDialog {
    enum Choice { case hide, delete, cancel }

    static func choose(for shelf: Shelf) -> Choice {
        let alert = makeAlert(for: shelf)
        let cancelResponse = NSApplication.ModalResponse(
            rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + alert.buttons.count - 1
        )
        let keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let handled = MainActor.assumeIsolated {
                guard NSApp.modalWindow === alert.window,
                      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                      [36, 53, 76].contains(event.keyCode) else { return false }
                if !event.isARepeat { NSApp.stopModal(withCode: cancelResponse) }
                return true
            }
            return handled ? nil : event
        }
        defer { if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) } }
        NSApp.activate()
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn: return alert.buttons.count == 3 ? .hide : .delete
        case .alertSecondButtonReturn: return alert.buttons.count == 3 ? .delete : .cancel
        default: return .cancel
        }
    }

    static func makeAlert(for shelf: Shelf) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Delete “\(shelf.name)”?"
        alert.informativeText = "Delete removes this shelf, its stored copies, and its version history. Original files stay where they are. Hide keeps the shelf and everything on it."
        if shelf.shouldDeleteWhenHidden {
            alert.informativeText = "This empty shelf will be removed. Original files are unchanged."
        } else {
            let hide = alert.addButton(withTitle: "Hide")
            hide.keyEquivalent = ""
        }
        let delete = alert.addButton(withTitle: "Delete")
        delete.hasDestructiveAction = true
        delete.keyEquivalent = ""
        let cancel = alert.addButton(withTitle: "Cancel")
        cancel.keyEquivalent = "\r"
        cancel.keyEquivalentModifierMask = []
        cancel.image = NSImage(systemSymbolName: "return", accessibilityDescription: "Return")
        cancel.imagePosition = .imageTrailing
        cancel.setAccessibilityLabel("Cancel")
        alert.window.defaultButtonCell = cancel.cell as? NSButtonCell
        alert.window.initialFirstResponder = cancel
        return alert
    }
}
