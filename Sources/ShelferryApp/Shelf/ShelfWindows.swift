import AppKit
import ShelferryCore

/// One floating panel per shelf. Decides which shelves are shown, makes new ones and closes
/// them, and runs shelf commands from the menu and CLI.
@MainActor
final class ShelfWindows {
    let library: ShelfLibrary
    var onSettings: () -> Void = {}
    private(set) var isEnabled = true
    private var config = ShelfConfig()
    private var controllers: [Shelf.ID: ShelfPanelController] = [:]
    /// The empty shelf that appeared for a Shift-drag. It goes away if nothing is dropped on it.
    private var dragShelfID: Shelf.ID?

    init(library: ShelfLibrary) {
        self.library = library
    }

    /// Brings back the saved shelves.
    func start(showWindows: Bool = true) throws {
        try library.load()
        if isEnabled && showWindows { showAll() }
    }

    func apply(_ config: ShelfConfig) {
        self.config = config
        isEnabled = config.enabled
        controllers.values.forEach { $0.setKeepOnTop(config.keepShelvesOnTop) }
        library.shelves.forEach { $0.removeAfterDragOut = config.removeAfterDragOut }
        if !isEnabled { hideAll() }
    }

    var isAnyVisible: Bool { controllers.values.contains(where: \.isVisible) }

    func isVisible(_ shelf: Shelf) -> Bool { controllers[shelf.id]?.isVisible == true }

    /// Hides every shelf if any is showing; otherwise shows them all, or a new one if there are none.
    func toggleAll() {
        guard isEnabled else { return NSSound.beep() }
        if isAnyVisible {
            hideAll()
        } else if library.isEmpty {
            newShelf()
        } else {
            showAll()
        }
    }

    func showAll() {
        guard isEnabled else { return NSSound.beep() }
        library.shelves.forEach { show($0) }
    }

    func hideAll() {
        let visible = controllers.values.filter(\.isVisible)
        let frame = visible.first?.frame
        library.shelves.forEach { hide($0, showFeedback: false) }
        if let frame { ShelfActionHUD.show(.hidden, count: visible.count, where: frame) }
    }

    /// Makes an empty shelf and shows it, by default with keyboard focus, ready for a drop or ⌘V.
    @discardableResult
    func newShelf(named name: String? = nil, focus: Bool = true) -> Shelf {
        let shelf = library.newShelf(named: name)
        show(shelf, focus: focus)
        return shelf
    }

    func show(_ shelf: Shelf, focus: Bool = false) {
        guard isEnabled else { return NSSound.beep() }
        let neighbour = library.shelves.lazy
            .filter { $0.id != shelf.id }
            .compactMap { self.controllers[$0.id]?.frame }
            .last
        controller(for: shelf).show(besides: neighbour, focus: focus)
    }

    func hide(_ shelf: Shelf, showFeedback: Bool = true) {
        guard let controller = controllers[shelf.id], controller.isVisible else { return }
        let frame = controller.frame
        controller.hide()
        if showFeedback, let frame { ShelfActionHUD.show(.hidden, where: frame) }
    }

    /// Removes the panel and shelf immediately after deletion is confirmed.
    func close(_ shelf: Shelf, showFeedback: Bool = true) {
        let controller = controllers.removeValue(forKey: shelf.id)
        let frame = controller?.frame
        controller?.hide()
        library.remove(shelf)
        if showFeedback, let frame { ShelfActionHUD.show(.deleted, where: frame) }
    }

    /// CLI deletion completes before its response is returned.
    func removeImmediately(_ shelf: Shelf) {
        close(shelf)
    }

    func closeAll() {
        let count = library.shelves.count
        let frame = controllers.values.first(where: \.isVisible)?.frame
        library.shelves.forEach { close($0, showFeedback: false) }
        if let frame { ShelfActionHUD.show(.deleted, count: count, where: frame) }
    }

    /// Asks first, since this throws away Shelferry's copies on every shelf.
    func confirmCloseAll() {
        guard !library.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Clear all shelves?"
        alert.informativeText = """
        This closes \(ShelfText.shelfCount(library.shelves.count).lowercased()) with \
        \(ShelfText.itemCount(library.itemCount).lowercased()). Originals stay where they are; \
        Shelferry's copies are deleted.
        """
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { closeAll() }
    }

    /// Clear keeps its existing second-click confirmation; shelf deletion uses a dialog.
    private func requestClear(on shelf: Shelf) {
        guard !shelf.hasCopies || shelf.armed == .clear else { return shelf.arm(.clear) }
        shelf.disarm()
        shelf.clear()
    }

    private func requestDelete(on shelf: Shelf) {
        switch ShelfDeleteDialog.choose(for: shelf) {
        case .hide: hide(shelf)
        case .delete: close(shelf)
        case .cancel: show(shelf, focus: true)
        }
    }

    /// Shows an empty shelf next to the pointer while something is Shift-dragged.
    func showForDrag() {
        guard isEnabled, dragShelfID == nil else { return }
        let shelf = library.newShelf()
        dragShelfID = shelf.id
        controller(for: shelf).show(nearCursor: true)
    }

    /// The drop arrives just after the mouse goes up, so wait a moment before deciding.
    func dragEnded() {
        guard let id = dragShelfID else { return }
        dragShelfID = nil
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if let shelf = library.shelves.first(where: { $0.id == id }), shelf.isEmpty { close(shelf, showFeedback: false) }
        }
    }

    private func controller(for shelf: Shelf) -> ShelfPanelController {
        if let existing = controllers[shelf.id] { return existing }
        let controller = ShelfPanelController(shelf: shelf)
        controller.setKeepOnTop(config.keepShelvesOnTop)
        shelf.removeAfterDragOut = config.removeAfterDragOut
        controller.onHide = { [weak self, weak shelf] in
            if let shelf { self?.hide(shelf) }
        }
        controller.onNewShelf = { [weak self] in self?.newShelf() }
        controller.onSettings = { [weak self] in self?.onSettings() }
        controller.onDelete = { [weak self, weak shelf] in
            if let shelf { self?.requestDelete(on: shelf) }
        }
        controller.onClear = { [weak self, weak shelf] in
            if let shelf { self?.requestClear(on: shelf) }
        }
        controllers[shelf.id] = controller
        return controller
    }
}
