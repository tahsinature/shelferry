import Foundation
import Testing
@testable import ShelferryApp

struct BuildInfoTests {
    @Test func readsUTCBuildDateAndUpdatesAgeAcrossMenuOpenings() throws {
        let info = BuildInfo(info: ["ShelferryBuildChannel": "prod", "ShelferryBuildDate": "2026-11-17T15:00:00Z"])
        let built = try #require(info.date)
        #expect(info.menuTitle(now: built) == "About Shelferry · Prod · Built just now")
        #expect(info.menuTitle(now: built.addingTimeInterval(60)) == "About Shelferry · Prod · Built 1m ago")
        #expect(info.menuTitle(now: built.addingTimeInterval(7_200)) == "About Shelferry · Prod · Built 2h ago")
        #expect(info.menuTitle(now: built.addingTimeInterval(86_400)) == "About Shelferry · Prod · Built 1d ago")
        #expect(info.menuTitle(now: built.addingTimeInterval(-60)).hasSuffix("Build date is in the future"))
    }

    @Test func oldAndUnbundledBuildsDoNotInventATimestamp() {
        let missing = BuildInfo(info: [:])
        #expect(missing.menuTitle() == "About Shelferry · Dev · Build date unavailable")
        let invalid = BuildInfo(info: ["ShelferryBuildDate": "invalid"])
        #expect(invalid.date == nil)
        #expect(invalid.exactDate == "Build date unavailable")
    }
}
