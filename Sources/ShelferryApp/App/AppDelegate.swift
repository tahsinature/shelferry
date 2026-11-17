import AppKit
import ShelferryCore
import ShelferryProtocol

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let library = ShelfLibrary()
    lazy var windows = ShelfWindows(library: library)
    lazy var handler = CommandHandler(windows: windows)
    private let server = CommandServer()
    private let dragWatcher = ShelfDragWatcher()
    private var statusItem: NSStatusItem?
    private lazy var preferences = PreferencesStore()
    private lazy var hotkeys = GlobalHotkeys()
    private lazy var preferencesWindow = PreferencesWindow(store: preferences, hotkeys: hotkeys)

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
        handler.onSettings = { [weak self] in self?.preferencesWindow.show() }
        preferences.onChange = { [weak self] value in self?.applyPreferences(value) }
        hotkeys.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .toggle: windows.toggleAll()
            case .newShelf: windows.newShelf()
            }
        }
        let background = CommandLine.arguments.contains("--background")
        do { try windows.start(showWindows: !background) } catch {
            let alert = NSAlert()
            alert.messageText = "Shelferry could not load its saved shelves"
            alert.informativeText = error.localizedDescription + " Your saved data has not been replaced."
            alert.runModal()
            NSApp.terminate(nil); return
        }
        dragWatcher.onShiftDrag = { [weak self] in self?.windows.showForDrag() }
        dragWatcher.onDragEnded = { [weak self] in self?.windows.dragEnded() }
        applyPreferences(preferences.value)
        if library.isEmpty && !background { windows.newShelf(focus: false) }
    }

    private func buildMenu() {
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        let buildLabel = Bundle.main.object(forInfoDictionaryKey: "ShelferryBuildChannel") as? String == "prod" ? "Prod" : "Dev"
        let menuTitle = "Shelferry · \(buildLabel)"
        statusItem?.button?.image = MenuBarIcon.paperStack()
        statusItem?.button?.toolTip = menuTitle
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: menuTitle, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        func item(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self; menu.addItem(item); return item
        }
        _ = item("New Shelf", #selector(newShelf), key: "n")
        _ = item("Show / Hide All Shelves", #selector(toggle), key: "s")
        menu.addItem(.separator())
        item("Show When Shift-Dragging", #selector(toggleDrag)).state = preferences.value.shiftDragOpens ? .on : .off
        item("Remove Items After Dragging Out", #selector(toggleCleanup)).state = preferences.value.removeAfterDragOut ? .on : .off
        menu.addItem(.separator())
        _ = item("Settings…", #selector(showPreferences), key: ",")
        _ = item("About Shelferry", #selector(about))
        _ = item("Quit Shelferry", #selector(quit), key: "q")
        statusItem?.menu = menu
    }
    @objc private func newShelf() { windows.newShelf() }
    @objc private func toggle() { windows.toggleAll() }
    private func applyPreferences(_ value: Preferences) {
        var config = ShelfConfig()
        config.shiftDragOpens = value.shiftDragOpens
        config.removeAfterDragOut = value.removeAfterDragOut
        windows.apply(config)
        value.shiftDragOpens ? dragWatcher.start() : dragWatcher.stop()
        hotkeys.apply(value.shortcuts)
        buildMenu()
    }
    @objc private func toggleDrag() { preferences.update { $0.shiftDragOpens.toggle() } }
    @objc private func toggleCleanup() { preferences.update { $0.removeAfterDragOut.toggle() } }
    @objc private func showPreferences() { preferencesWindow.show() }
    @objc private func about() { preferencesWindow.show(.about) }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows.showAll(); return false
    }
}
