import AppKit
import SwiftUI
import Testing
@testable import ShelferryApp

@MainActor
struct ShelfPanelTests {
    @Test func escapeHidesOnKeyDownWithoutChangingShelfPresentation() throws {
        _ = NSApplication.shared
        let shelf = Shelf(name: "Escape test")
        let item = ShelfItem(fileURL: URL(fileURLWithPath: "/tmp/shelferry-escape-fixture.txt"))
        shelf.add([item])
        shelf.isExpanded = true
        shelf.showDetail(of: item)
        let panel = ShelfPanel(shelf: shelf, content: EmptyView())
        var hidden = 0
        panel.onHide = { hidden += 1 }

        panel.sendEvent(try escape(.keyDown, window: panel))
        #expect(hidden == 1)
        #expect(shelf.isExpanded)
        #expect(shelf.isShowingDetail)
        #expect(shelf.items.count == 1)

        panel.sendEvent(try escape(.keyDown, window: panel, repeated: true))
        panel.sendEvent(try escape(.keyUp, window: panel))
        #expect(hidden == 1)
    }

    @Test func escapeAlsoHidesWhileEditingOrConverting() throws {
        _ = NSApplication.shared
        let shelf = Shelf(name: "Editing test")
        let panel = ShelfPanel(shelf: shelf, content: EmptyView())
        let editor = NSTextView(frame: .zero)
        panel.contentView?.addSubview(editor)
        panel.makeFirstResponder(editor)
        shelf.isShowingConversion = true
        var hidden = false
        panel.onHide = { hidden = true }

        panel.sendEvent(try escape(.keyDown, window: panel))
        #expect(hidden)
        #expect(shelf.isShowingConversion)
    }

    private func escape(_ type: NSEvent.EventType, window: NSWindow, repeated: Bool = false) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
                                     charactersIgnoringModifiers: "\u{1b}", isARepeat: repeated, keyCode: 53))
    }
}
