import AppKit
import SwiftUI

@MainActor
final class ShelfSettingsWindow {
    private weak var shelf: Shelf?
    private var window: NSWindow?

    init(shelf: Shelf) { self.shelf = shelf }

    func show() {
        guard let shelf else { return }
        if window?.isVisible != true {
            let model = ShelfSettingsModel(shelf: shelf)
            let host = NSHostingController(rootView: ShelfSettingsView(model: model))
            let window = ShelfSettingsNativeWindow(contentViewController: host)
            window.title = "\(shelf.name) Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 600, height: 610))
            window.minSize = NSSize(width: 540, height: 510)
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close(); window = nil }
}
