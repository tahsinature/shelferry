import AppKit
import ShelferryCore
import ShelferryProtocol

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let library = ShelfLibrary()
    lazy var windows = ShelfWindows(library: library)
    lazy var manager = ShelfManagerController(windows: windows)
    lazy var handler = CommandHandler(windows: windows, manager: manager)
    private let server = CommandServer()
    private let dragWatcher = ShelfDragWatcher()
    private var statusItem: NSStatusItem?
    private var settings = ShelfConfig()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try server.start { [weak self] request in
                guard let self else { return Response(error: "Shelferry is shutting down.") }
                return await handler.handle(request)
            }
        } catch {
            // A second launch must never load or mutate the first instance's data.
            NSLog("Shelferry: %@", error.localizedDescription)
            NSApp.terminate(nil); return
        }
        settings.shiftDragOpens = UserDefaults.standard.object(forKey: "shiftDragOpens") as? Bool ?? true
        settings.removeAfterDragOut = UserDefaults.standard.bool(forKey: "removeAfterDragOut")
        windows.apply(settings)
        do { try windows.start() } catch {
            let alert = NSAlert()
            alert.messageText = "Shelferry could not load its saved shelves"
            alert.informativeText = error.localizedDescription + " Your saved data has not been replaced."
            alert.runModal()
            NSApp.terminate(nil); return
        }
        dragWatcher.onShiftDrag = { [weak self] in self?.windows.showForDrag() }
        dragWatcher.onDragEnded = { [weak self] in self?.windows.dragEnded() }
        if settings.shiftDragOpens { dragWatcher.start() }
        buildMenu()
        if library.isEmpty && ProcessInfo.processInfo.environment["SHELFERRY_DATA_DIR"] == nil { windows.newShelf(focus: false) }
    }

    private func buildMenu() {
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        statusItem?.button?.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Shelferry")
        statusItem?.button?.toolTip = "Shelferry"
        let menu = NSMenu()
        func item(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self; menu.addItem(item); return item
        }
        _ = item("New Shelf", #selector(newShelf), key: "n")
        _ = item("Show / Hide All Shelves", #selector(toggle), key: "s")
        _ = item("Shelf Manager…", #selector(showManager))
        menu.addItem(.separator())
        item("Show When Shift-Dragging", #selector(toggleDrag)).state = settings.shiftDragOpens ? .on : .off
        item("Remove Items After Dragging Out", #selector(toggleCleanup)).state = settings.removeAfterDragOut ? .on : .off
        menu.addItem(.separator())
        _ = item("About Shelferry", #selector(about))
        _ = item("Quit Shelferry", #selector(quit), key: "q")
        statusItem?.menu = menu
    }
    @objc private func newShelf() { windows.newShelf() }
    @objc private func toggle() { windows.toggleAll() }
    @objc private func showManager() { manager.toggle(library: library) }
    @objc private func toggleDrag() {
        settings.shiftDragOpens.toggle()
        UserDefaults.standard.set(settings.shiftDragOpens, forKey: "shiftDragOpens")
        settings.shiftDragOpens ? dragWatcher.start() : dragWatcher.stop()
        buildMenu()
    }
    @objc private func toggleCleanup() {
        settings.removeAfterDragOut.toggle()
        UserDefaults.standard.set(settings.removeAfterDragOut, forKey: "removeAfterDragOut")
        windows.apply(settings); buildMenu()
    }
    @objc private func about() { NSApp.activate(); NSApp.orderFrontStandardAboutPanel(nil) }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows.showAll(); return false
    }
}
