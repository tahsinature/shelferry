import ComposableArchitecture
import Foundation
import ShelfFeature
import Testing

@MainActor
struct ShelfFeatureTests {
    @Test func selectionSupportsKeyboardExtensionAndRemoval() async {
        let ids = (0..<4).map { _ in UUID() }
        let store = TestStore(initialState: ShelfFeature.State(itemIDs: ids)) { ShelfFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.moveSelection(-1, extending: false))
        #expect(store.state.cursor == ids.last)
        await store.send(.moveSelection(Int.min, extending: true))
        #expect(store.state.selection == [ids[0], ids[3]])
        await store.send(.clicked(ids[0], extending: true))
        #expect(store.state.selection == [ids[3]])
        await store.send(.showDetail(ids[3]))
        await store.send(.expanded(true))
        await store.send(.itemsChanged([]))
        #expect(store.state.selection.isEmpty)
        #expect(store.state.cursor == nil)
        #expect(!store.state.isShowingDetail)
        #expect(!store.state.isExpanded)
    }

    @Test func rearmingRestartsConfirmationExpiry() async {
        let clock = TestClock()
        let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() } withDependencies: {
            $0.continuousClock = clock
        }
        await store.send(.arm(.clear)) { $0.armed = .clear }
        await clock.advance(by: .seconds(3))
        await store.send(.arm(.delete)) { $0.armed = .delete }
        await clock.advance(by: .seconds(3))
        #expect(store.state.armed == .delete)
        await clock.advance(by: .seconds(1))
        await store.receive(.disarm) { $0.armed = nil }
        await store.finish()
    }

}
