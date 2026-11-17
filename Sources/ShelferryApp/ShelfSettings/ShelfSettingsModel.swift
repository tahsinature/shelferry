import AppKit
import Observation

@MainActor @Observable
final class ShelfSettingsModel {
    var draft: ShelfConnectionSettings
    var headers = ""
    var curl = ""
    var limitGB = ""
    var error: String?
    var testResult: String?
    var isTesting = false
    var needsConfirmation = false
    var confirmsHistoryRemoval = false
    let shelf: Shelf

    init(shelf: Shelf) {
        self.shelf = shelf
        draft = shelf.connectionSettings
        limitGB = String(Double(draft.limitBytes) / 1_000_000_000)
        do { headers = try ConnectionCredentials.read(draft.credentialID) }
        catch { self.error = error.localizedDescription }
    }

    var changeSummary: String {
        let managed = shelf.items.filter { $0.connectionKey != nil }.count
        let manual = shelf.items.count - managed
        if draft.source == .regular {
            return "Disconnect this source. Keep the current shelf items and existing file history. Automatic refresh will stop."
        }
        var summary = "Connect to \(draft.source == .folder ? "the selected folder" : "the remote URL") using \(draft.mode.rawValue)."
        if draft.location != shelf.connectionSettings.location || draft.source != shelf.connectionSettings.source {
            summary += " The \(managed) currently connected items will be replaced after a successful refresh."
        }
        if draft.mode == .mirror && manual > 0 {
            summary += " The \(manual) manually added items will be removed from this shelf after a successful refresh. Original files are kept."
        }
        if draft.usesReferences { summary += " References point to the originals; editing or moving them affects the source." }
        return summary
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { draft.location = url.path }
    }

    func importCurl() {
        do {
            let request = try CurlRequestImport.parse(curl)
            draft.location = request.url
            headers = request.headers
            curl = ""
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func validated() throws -> ShelfConnectionSettings {
        guard let number = Double(limitGB.isEmpty ? "1" : limitGB), number.isFinite,
              number > 0, number <= 1_000_000 else { throw ConnectionError("Enter a storage limit in GB greater than zero.") }
        var settings = draft
        settings.limitBytes = Int64(number * 1_000_000_000)
        return try settings.validated()
    }

    func requestApply() {
        do {
            _ = try validated()
            _ = try ConnectionCredentials.headers(headers)
            error = nil
            needsConfirmation = true
        } catch { self.error = error.localizedDescription }
    }

    func apply() {
        do {
            try shelf.connection.apply(validated(), headers: headers)
            draft = shelf.connectionSettings
            error = nil
            testResult = "Settings saved."
        } catch { self.error = error.localizedDescription }
    }

    func test() {
        guard !isTesting else { return }
        isTesting = true
        error = nil
        testResult = nil
        Task {
            defer { isTesting = false }
            do {
                let settings = try validated()
                let requestHeaders = try ConnectionCredentials.headers(headers)
                let count = try await Task.detached(priority: .utility) {
                    let source = try await ConnectionSource.load(settings, headers: requestHeaders)
                    defer { if let temporary = source.temporary { try? FileManager.default.removeItem(at: temporary) } }
                    let entries = try ConnectionFiles.scan(source.root, settings: settings)
                    return entries.filter { !$0.path.contains("/") }.count
                }.value
                testResult = "Connection succeeded. Found \(count) top-level items. Nothing was imported."
            } catch { self.error = error.localizedDescription }
        }
    }

    func clearHistory() {
        do { try shelf.connection.clearHistory(); error = nil }
        catch { self.error = error.localizedDescription }
    }

    func export(_ version: ConnectionManifest.Version) {
        guard let source = shelf.connection.versionURL(version) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (version.path as NSString).lastPathComponent
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            // NSSavePanel asks before replacing an existing destination.
            let data = try Data(contentsOf: source, options: .mappedIfSafe)
            try data.write(to: destination, options: .atomic)
        } catch { self.error = error.localizedDescription }
    }
}
