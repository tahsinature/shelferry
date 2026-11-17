import AppKit
import QuartzCore
import ShelferryCore

/// The floating panel for one shelf: shows and places it, and handles its keys.
/// `ShelfWindows` decides which shelves are shown.
@MainActor
final class ShelfPanelController {
    let shelf: Shelf
    /// Esc hides the shelf. The trash button opens its deletion dialog.
    var onHide: () -> Void = {}
    var onDelete: () -> Void = {}
    var onClear: () -> Void = {}
    /// Run by ⌘N.
    var onNewShelf: () -> Void = {}
    var onSettings: () -> Void = {}
    private lazy var panel = makePanel()
    private var hasBeenPlaced = false
    /// Tells a size change from folding or unfolding apart from others. The details page
    /// animates its own height, so the window just follows it.
    private var wasExpanded = false

    init(shelf: Shelf) {
        self.shelf = shelf
        wasExpanded = shelf.isExpanded
    }

    var isVisible: Bool { hasBeenPlaced && panel.isVisible }
    /// Where the panel is on screen, once it has been shown.
    var frame: CGRect? { hasBeenPlaced ? panel.frame : nil }

    func setKeepOnTop(_ enabled: Bool) {
        panel.isFloatingPanel = enabled
        panel.level = enabled ? .floating : .normal
    }

    /// - Parameters:
    ///   - nearCursor: Places the shelf next to the pointer, for a drag that's on its way.
    ///   - besides: The first time it's shown, places the shelf to the left of this frame.
    ///   - focus: Takes keyboard focus so ⌘V, Delete and Esc work right away.
    func show(nearCursor: Bool = false, besides neighbour: CGRect? = nil, focus: Bool = false) {
        if nearCursor {
            placeNearCursor()
        } else if !hasBeenPlaced {
            if let neighbour { place(besides: neighbour) } else { placeInCorner() }
        }
        hasBeenPlaced = true
        // Raise even a normal-level panel above the active app, without making it stay on top.
        panel.orderFrontRegardless()
        if focus { panel.makeKey() }
    }

    /// Hiding preserves the shelf and its current view, with no delay or transition.
    func hide() {
        guard isVisible else { return }
        panel.quickLook.close()
        shelf.disarm()
        panel.orderOut(nil)
    }

    private func makePanel() -> ShelfPanel {
        let view = ShelfView(
            shelf: shelf,
            onDelete: { [weak self] in self?.onDelete() },
            onClear: { [weak self] in self?.onClear() },
            onSizeChange: { [weak self] size in self?.fit(to: size) }
        )
        let panel = ShelfPanel(shelf: shelf, content: view)
        shelf.onQuickLook = { [weak panel] urls in panel?.quickLook.toggle(urls) }
        shelf.onCloseQuickLook = { [weak panel] in panel?.quickLook.close() }
        panel.onHide = { [weak self] in self?.onHide() }
        panel.onFocusChange = { [weak self] focused in
            self?.shelf.isFocused = focused
        }
        panel.quickLook.onArrowKey = { [weak self] event in self?.handleKey(event) ?? false }
        panel.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        return panel
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let shortcutModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let key = event.charactersIgnoringModifiers
        if shortcutModifiers == [.command, .shift], key == "," || key == "<" {
            if !event.isARepeat { shelf.settingsWindow.show() }
            return true
        }
        if shortcutModifiers == .command, key == "," {
            if !event.isARepeat { onSettings() }
            return true
        }
        if shelf.isShowingConversion, let model = shelf.imageConversion {
            if event.keyCode == 49 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "y") {
                model.quickLook()
                return true
            }
            if model.phase == .review, [123, 124, 125, 126].contains(event.keyCode) {
                model.moveReview(by: [123, 126].contains(event.keyCode) ? -1 : 1)
                panel.quickLook.update(model.reviewURLs)
                return true
            }
            return false
        }
        // While the name is being edited, keys belong to the text field.
        if panel.firstResponder is NSText { return false }
        let commandKey = event.charactersIgnoringModifiers?.lowercased()
        if event.modifierFlags.contains(.command) {
            switch commandKey {
            case "v":
                if !shelf.add(from: .general) { NSSound.beep() }
            case "a":
                shelf.selection = Set(shelf.items.map(\.id))
            case "n":
                onNewShelf()
            default:
                return false
            }
            return true
        }
        if shelf.armed == .clear, [36, 76].contains(event.keyCode) { // Return or Enter confirms Clear
            onClear()
            return true
        }
        if !shelf.isExpanded, !shelf.isEmpty, [36, 76, 125].contains(event.keyCode) { // Return, Enter, Down
            shelf.isExpanded = true
            if event.keyCode == 125 { shelf.moveSelection(by: 1, extending: false) }
            return true
        }
        if event.keyCode == 49 { // Space
            shelf.onQuickLook(previewURLs)
            return true
        }
        if event.keyCode == 124, shelf.isExpanded, !shelf.isEmpty { // Right: the item's details
            if shelf.selection.isEmpty || shelf.cursor == nil { shelf.moveSelection(by: 1, extending: false) }
            shelf.isShowingDetail = true
            return true
        }
        if event.keyCode == 123, shelf.detailItem != nil { // Left: back to the list
            shelf.isShowingDetail = false
            return true
        }
        let arrows: [UInt16: Int] = [125: 1, 126: -1] // Down and Up
        if let offset = arrows[event.keyCode], !shelf.isEmpty {
            shelf.moveSelection(by: offset, extending: event.modifierFlags.contains(.shift))
            panel.quickLook.update(previewURLs)
            return true
        }
        let deleteKeys: Set<UInt16> = [51, 117] // Delete and Forward Delete
        guard deleteKeys.contains(event.keyCode), !shelf.selection.isEmpty else { return false }
        shelf.remove(shelf.selection)
        return true
    }

    /// The selection, or every item when nothing is selected. Copies still being made are left out.
    private var previewURLs: [URL] {
        let items = shelf.selection.isEmpty ? shelf.items : shelf.selectedItems
        return items.filter { !shelf.copyingIDs.contains($0.id) }.map(\.url)
    }

    /// Keeps the top-left corner in place as the content grows or shrinks.
    /// Switching views animates along with the content's spring.
    private func fit(to size: CGSize) {
        let isToggle = shelf.isExpanded != wasExpanded
        wasExpanded = shelf.isExpanded
        var frame = panel.frame
        guard frame.size != size else { return }
        frame.origin.y += frame.height - size.height
        frame.size = size
        guard isToggle, panel.isVisible else {
            panel.setFrame(onScreen(frame), display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = ShelfMotion.duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            panel.animator().setFrame(onScreen(frame), display: true)
        }
    }

    private func placeNearCursor() {
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = CGPoint(x: mouse.x + 60, y: mouse.y - size.height / 2)
        if let screen = screen(containing: mouse), origin.x + size.width > screen.visibleFrame.maxX {
            origin.x = mouse.x - 60 - size.width
        }
        panel.setFrame(onScreen(CGRect(origin: origin, size: size)), display: false)
    }

    private func place(besides neighbour: CGRect) {
        let size = panel.frame.size
        let origin = CGPoint(x: neighbour.minX - size.width - 12, y: neighbour.maxY - size.height)
        panel.setFrame(onScreen(CGRect(origin: origin, size: size)), display: false)
    }

    private func placeInCorner() {
        guard let visible = screen(containing: NSEvent.mouseLocation)?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = CGPoint(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }

    private func onScreen(_ frame: CGRect) -> CGRect {
        guard let visible = screen(containing: CGPoint(x: frame.midX, y: frame.midY))?.visibleFrame
            ?? NSScreen.main?.visibleFrame
        else { return frame }
        var frame = frame
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        return frame
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }
}
