import AppKit
import ShelferryCore
import ShelferryProtocol

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let library = ShelfLibrary()
    lazy var windows = ShelfWindows(library: library)
    lazy var handler = CommandHandler(windows: windows)
    private let updater = Updater()
    private var activeRequests = 0
    private let server = CommandServer()
    private let dragWatcher = ShelfDragWatcher()
    private var statusItem: NSStatusItem?
    private let buildInfo = BuildInfo()
    private weak var aboutMenuItem: NSMenuItem?
    private lazy var preferences = PreferencesStore()
    private lazy var hotkeys = GlobalHotkeys()
    private lazy var preferencesWindow = PreferencesWindow(store: preferences, hotkeys: hotkeys, updater: updater)

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try server.start { [weak self] request in
                guard let self else { return Response(error: "Shelferry is shutting down.") }
                activeRequests += 1
                defer { activeRequests -= 1 }
                return await handler.handle(request)
            }
        } catch {
            // A second launch must never load or mutate the first instance's data.
            NSLog("Shelferry: %@", error.localizedDescription)
            NSApp.terminate(nil); return
        }
        handler.onSettings = { [weak self] in self?.preferencesWindow.show() }
        windows.onSettings = { [weak self] in self?.preferencesWindow.show() }
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
        dragWatcher.onShiftReleased = { [weak self] in self?.windows.shiftReleased() }
        updater.hasPendingWork = { [weak self] in
            guard let self else { return false }
            return activeRequests > 0 || library.shelves.contains {
                !$0.copyingIDs.isEmpty || $0.imageConversion != nil || $0.connection.isRefreshing
            }
        }
        updater.start()
        applyPreferences(preferences.value)
        if library.isEmpty && !background { windows.newShelf(focus: false) }
    }

    private func buildMenu() {
        let isDevelopment = buildInfo.channel == "Dev"
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = statusItem?.button {
                button.image = MenuBarIcon.paperStack()
                if isDevelopment { MenuBarIcon.addDevelopmentBadge(to: button) }
            }
        }
        statusItem?.button?.toolTip = "Shelferry · \(buildInfo.channel)"
        let menu = NSMenu()
        menu.delegate = self
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
        if updater.isEnabled { _ = item("Check for Updates…", #selector(checkForUpdates)) }
        aboutMenuItem = item(buildInfo.menuTitle(), #selector(about))
        aboutMenuItem?.toolTip = buildInfo.exactDate
        _ = item("Quit Shelferry", #selector(quit), key: "q")
        statusItem?.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        aboutMenuItem?.title = buildInfo.menuTitle()
    }
    @objc private func newShelf() { windows.newShelf() }
    @objc private func toggle() { windows.toggleAll() }
    private func applyPreferences(_ value: Preferences) {
        var config = ShelfConfig()
        config.keepShelvesOnTop = value.keepShelvesOnTop
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
    @objc private func checkForUpdates() { updater.check() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows.showAll(); return false
    }
}
