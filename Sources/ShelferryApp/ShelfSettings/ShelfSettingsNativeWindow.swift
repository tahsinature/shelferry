import AppKit

/// Shelferry has no standard app menu, so this window handles its close shortcuts itself.
final class ShelfSettingsNativeWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if !handleCloseShortcut(event) { super.sendEvent(event) }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handleCloseShortcut(event) || super.performKeyEquivalent(with: event)
    }

    private func handleCloseShortcut(_ event: NSEvent) -> Bool {
        // Let confirmations and file pickers handle their own Escape/Cancel actions.
        guard event.type == .keyDown, attachedSheet == nil else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let isEscape = modifiers.isEmpty && event.keyCode == 53
        let isClose = modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "w"
        guard isEscape || isClose else { return false }
        if !event.isARepeat { performClose(nil) }
        return true
    }
}
