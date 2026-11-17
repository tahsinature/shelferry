import AppKit
import Observation
import Sparkle

/// Sparkle owns checking, update presentation, download, verification and installation.
/// Development builds never create or start an updater.
@MainActor
@Observable
final class Updater: NSObject, SPUUpdaterDelegate {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case failed(String)
    }

    private(set) var state = State.idle
    private(set) var lastChecked: Date?
    private(set) var canCheck = false
    private(set) var checksAutomatically = false
    let isEnabled: Bool
    @ObservationIgnored var hasPendingWork: () -> Bool = { false }

    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    private static var isProduction: Bool {
        Bundle.main.object(forInfoDictionaryKey: "ShelferryBuildChannel") as? String == "prod"
            && ProcessInfo.processInfo.environment["SHELFERRY_DATA_DIR"] == nil
    }

    init(isRelease: Bool = Updater.isProduction) {
        isEnabled = isRelease
        super.init()
    }

    func start() {
        guard isEnabled, controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        let updater = controller.updater
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
            },
            updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.checksAutomatically = updater.automaticallyChecksForUpdates }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.lastChecked = updater.lastUpdateCheckDate }
            },
        ]
        do {
            try updater.start()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func setChecksAutomatically(_ enabled: Bool) {
        guard isEnabled, let updater = controller?.updater,
              updater.automaticallyChecksForUpdates != enabled else { return }
        updater.automaticallyChecksForUpdates = enabled
    }

    func check() {
        guard isEnabled, let controller, canCheck else { return }
        state = .checking
        controller.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        state = .available(item.displayVersionString)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        state = Self.stateAfterCycle(error: error)
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard hasPendingWork() else { return false }
        Task { @MainActor in
            while hasPendingWork() {
                try? await Task.sleep(for: .seconds(1))
            }
            installHandler()
        }
        return true
    }

    static func stateAfterCycle(error: Error?) -> State {
        if let error = error as NSError? {
            if error.domain == SUSparkleErrorDomain && error.code == SUError.noUpdateError.rawValue {
                return .upToDate
            } else if error.domain == SUSparkleErrorDomain && error.code == SUError.installationCanceledError.rawValue {
                return .idle
            } else {
                return .failed(error.localizedDescription)
            }
        } else {
            return .idle
        }
    }
}
