import AppKit
import SwiftUI

/// Brief, noninteractive feedback at the shelf's former position.
@MainActor
enum ShelfActionHUD {
    enum Action {
        case hidden, deleted

        var symbol: String { self == .hidden ? "eye.slash" : "trash" }
        func title(count: Int) -> String {
            let subject = count == 1 ? "Shelf" : "\(count) shelves"
            return "\(subject) \(self == .hidden ? "hidden" : "deleted")"
        }
        var detail: String {
            self == .hidden ? "Show shelves again from the menu bar." : "Original files are unchanged."
        }
    }

    private static var panel: NSPanel?
    private static var dismissal: Task<Void, Never>?

    static func show(_ action: Action, count: Int = 1, where frame: CGRect) {
        show(title: action.title(count: count), detail: action.detail, symbol: action.symbol, where: frame)
    }

    static func show(hiddenCount: Int, deletedCount: Int, where frame: CGRect) {
        if deletedCount == 0 {
            show(.hidden, count: hiddenCount, where: frame)
        } else if hiddenCount == 0 {
            show(.deleted, count: deletedCount, where: frame)
        } else {
            show(title: "\(hiddenCount) hidden · \(deletedCount) empty deleted",
                 detail: "Show hidden shelves again from the menu bar.", symbol: "eye.slash", where: frame)
        }
    }

    private static func show(title: String, detail: String, symbol: String, where frame: CGRect) {
        dismissal?.cancel()
        panel?.orderOut(nil)
        // Each toast owns its panel, so an older fade cannot dismiss newer feedback.
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView(title: title, detail: detail, symbol: symbol))
        let size = panel.contentView?.fittingSize ?? .zero
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        self.panel = panel
        panel.orderFrontRegardless()
        dismissal = Task {
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                await NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    panel.animator().alphaValue = 0
                }
            }
            panel.orderOut(nil)
        }
    }

    private struct HUDView: View {
        let title: String
        let detail: String
        let symbol: String

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
            .fixedSize()
        }
    }
}
