import Foundation
import Sparkle
import Testing
@testable import ShelferryApp

@MainActor
struct UpdaterTests {
    @Test func developmentBuildDoesNotStartUpdater() {
        let updater = Updater(isRelease: false)
        updater.start()
        updater.setChecksAutomatically(true)
        updater.check()
        #expect(!updater.canCheck)
        #expect(!updater.checksAutomatically)
        #expect(updater.state == .idle)
        #expect(updater.lastChecked == nil)
    }

    @Test func updateCycleClassifiesErrors() {
        #expect(Updater.stateAfterCycle(error: nil) == .idle)
        #expect(Updater.stateAfterCycle(error: NSError(domain: SUSparkleErrorDomain,
            code: Int(SUError.noUpdateError.rawValue))) == .upToDate)
        #expect(Updater.stateAfterCycle(error: NSError(domain: SUSparkleErrorDomain,
            code: Int(SUError.installationCanceledError.rawValue))) == .idle)
        let failure = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        #expect(Updater.stateAfterCycle(error: failure) == .failed(failure.localizedDescription))
    }
}
