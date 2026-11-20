import AppKit
import SwiftUI
import Testing
@testable import ShelferryApp

@MainActor
struct ShelfPanelTests {
    @Test(arguments: [UInt16(51), 53, 117], [false, true])
    func commandDeleteAndEscapeRequestDeletionWithoutChangingShelf(keyCode: UInt16, expanded: Bool) throws {
        _ = NSApplication.shared
        let shelf = Shelf(name: "Delete shortcut test")
        let item = ShelfItem(fileURL: URL(fileURLWithPath: "/tmp/shelferry-shortcut-fixture.txt"))
        shelf.add([item])
        shelf.selection = [item.id]
        shelf.isExpanded = expanded
        let panel = ShelfPanel(shelf: shelf, content: EmptyView())
        var deletions = 0
        var hides = 0
        panel.onDelete = { deletions += 1 }
        panel.onHide = { hides += 1 }

        func key(_ type: NSEvent.EventType, repeated: Bool = false) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: .command, timestamp: 0,
                                         windowNumber: panel.windowNumber, context: nil, characters: "",
                                         charactersIgnoringModifiers: "", isARepeat: repeated, keyCode: keyCode))
        }

        panel.sendEvent(try key(.keyDown))
        #expect(deletions == 1)
        panel.sendEvent(try key(.keyDown, repeated: true))
        panel.sendEvent(try key(.keyUp))
        #expect(deletions == 1)

        #expect(panel.performKeyEquivalent(with: try key(.keyDown)))
        #expect(deletions == 2)
        #expect(panel.performKeyEquivalent(with: try key(.keyDown, repeated: true)))
        #expect(deletions == 2)
        #expect(hides == 0)
        #expect(shelf.isExpanded == expanded)
        #expect(shelf.items.map(\.id) == [item.id])
        #expect(shelf.selection == [item.id])
    }

    @Test(arguments: [false, true])
    func escapeFoldsBeforeHiding(showDetails: Bool) throws {
        _ = NSApplication.shared
        let shelf = Shelf(name: "Escape test")
        let item = ShelfItem(fileURL: URL(fileURLWithPath: "/tmp/shelferry-escape-fixture.txt"))
        shelf.add([item])
        shelf.isExpanded = true
        if showDetails { shelf.showDetail(of: item) }
        let panel = ShelfPanel(shelf: shelf, content: EmptyView())
        var hidden = 0
        panel.onHide = { hidden += 1 }

        panel.sendEvent(try escape(.keyDown, window: panel))
        #expect(hidden == 0)
        #expect(!shelf.isExpanded)
        #expect(!shelf.isShowingDetail)
        #expect(shelf.items.count == 1)

        panel.sendEvent(try escape(.keyDown, window: panel, repeated: true))
        panel.sendEvent(try escape(.keyUp, window: panel))
        #expect(hidden == 0)

        panel.sendEvent(try escape(.keyDown, window: panel))
        #expect(hidden == 1)
    }

    @Test func escapeAlsoHidesWhileEditingOrConverting() throws {
        _ = NSApplication.shared
        let shelf = Shelf(name: "Editing test")
        let panel = ShelfPanel(shelf: shelf, content: EmptyView())
        let editor = NSTextView(frame: .zero)
        panel.contentView?.addSubview(editor)
        panel.makeFirstResponder(editor)
        shelf.isExpanded = true
        shelf.isShowingConversion = true
        var hidden = false
        panel.onHide = { hidden = true }

        panel.sendEvent(try escape(.keyDown, window: panel))
        #expect(hidden)
        #expect(shelf.isExpanded)
        #expect(shelf.isShowingConversion)
    }

    private func escape(_ type: NSEvent.EventType, window: NSWindow, repeated: Bool = false) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
                                     charactersIgnoringModifiers: "\u{1b}", isARepeat: repeated, keyCode: 53))
    }
}
