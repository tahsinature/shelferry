import AppKit
import Observation

/// Copies shelf files and keeps a short-lived confirmation for the footer.
@MainActor
@Observable
final class ShelfClipboard {
    private(set) var copiedCount: Int?
    @ObservationIgnored private var dismissal: Task<Void, Never>?

    func copy(_ items: [ShelfItem], excluding pendingIDs: Set<ShelfItem.ID>, to pasteboard: NSPasteboard = .general) {
        let urls = items.filter { $0.exists && !pendingIDs.contains($0.id) }.map(\.url)
        guard !urls.isEmpty else { return }
        pasteboard.clearContents()
        guard pasteboard.writeObjects(urls as [NSURL]) else { return }

        dismissal?.cancel()
        copiedCount = urls.count
        dismissal = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(1500)) }
            catch { return }
            self?.copiedCount = nil
        }
    }
}
