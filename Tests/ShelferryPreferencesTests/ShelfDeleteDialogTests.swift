import AppKit
import Testing
@testable import ShelferryApp

@MainActor
@Suite(.serialized)
struct ShelfDeleteDialogTests {
    @Test(arguments: [false, true])
    func hideIsAvailableOnlyWhenTheShelfWillBeKept(connected: Bool) {
        _ = NSApplication.shared
        let shelf = Shelf(name: "Delete dialog test")
        if connected { shelf.connectionSettings.source = .folder }
        let alert = ShelfDeleteDialog.makeAlert(for: shelf)

        #expect(alert.buttons.map(\.title) == (connected ? ["Hide", "Delete", "Cancel"] : ["Delete", "Cancel"]))
        #expect(alert.buttons.last?.keyEquivalent == "\r")
        #expect(alert.buttons.last?.keyEquivalentModifierMask.isEmpty == true)
        #expect(alert.buttons.dropLast().allSatisfy { $0.keyEquivalent.isEmpty })
        #expect(alert.window.defaultButtonCell === alert.buttons.last?.cell)
        #expect(alert.buttons.map(\.tag) == Array(1000..<(1000 + alert.buttons.count)))
    }
}
