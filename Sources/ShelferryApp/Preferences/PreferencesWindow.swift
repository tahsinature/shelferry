import AppKit
import SwiftUI

enum PreferencesPane: String, CaseIterable {
    case general = "General", hotkeys = "Hotkeys", about = "About"
    var symbol: String {
        switch self { case .general: "slider.horizontal.3"; case .hotkeys: "keyboard"; case .about: "info.circle" }
    }
    var identifier: NSToolbarItem.Identifier { .init(rawValue) }
}

@MainActor
final class PreferencesWindow: NSObject, NSToolbarDelegate {
    private let store: PreferencesStore
    private let hotkeys: GlobalHotkeys
    private var window: NSWindow?
    private var hosting: NSHostingController<PreferencesView>?

    init(store: PreferencesStore, hotkeys: GlobalHotkeys) { self.store = store; self.hotkeys = hotkeys }

    func show(_ pane: PreferencesPane = .general) {
        if window == nil {
            let host = NSHostingController(rootView: PreferencesView(pane: pane, store: store, hotkeys: hotkeys))
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.title = "Shelferry"
            window.toolbarStyle = .preference
            let toolbar = NSToolbar(identifier: "ShelferryPreferences")
            toolbar.delegate = self
            toolbar.displayMode = .iconAndLabel
            toolbar.allowsUserCustomization = false
            window.toolbar = toolbar
            self.window = window; hosting = host
            window.setContentSize(NSSize(width: 490, height: 360))
            window.center()
        }
        select(pane)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func select(_ pane: PreferencesPane) {
        hosting?.rootView = PreferencesView(pane: pane, store: store, hotkeys: hotkeys)
        window?.toolbar?.selectedItemIdentifier = pane.identifier
        window?.title = pane.rawValue
    }
    @objc private func selected(_ sender: NSToolbarItem) {
        guard let pane = PreferencesPane(rawValue: sender.itemIdentifier.rawValue) else { return }
        select(pane)
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { PreferencesPane.allCases.map(\.identifier) }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarAllowedItemIdentifiers(toolbar) }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarAllowedItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = PreferencesPane(rawValue: identifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = pane.rawValue
        item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.rawValue)
        item.target = self; item.action = #selector(selected)
        return item
    }
}
