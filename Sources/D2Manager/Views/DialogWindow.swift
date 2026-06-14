import SwiftUI
import AppKit

/// Hosts a SwiftUI view in a standalone `NSWindow`.
///
/// `MenuBarExtra(.window)` shows its content in a *transient* popover that
/// auto-dismisses when it resigns key focus. Any UI that opens its own dropdown
/// or menu (e.g. a `.menu`-style `Picker`) makes the popover resign key — so a
/// `.sheet` presented on the popover vanishes the moment you open such a control.
/// Presenting these dialogs as real windows avoids that entirely.
@MainActor
final class DialogWindow {
    private var window: NSWindow?

    /// Present `content` in a fresh window. The builder receives a `close` action
    /// that dismisses the window — `@Environment(\.dismiss)` does not drive a
    /// manually created `NSWindow`, so views call this instead.
    func present<Content: View>(
        title: String,
        model: AppModel,
        @ViewBuilder content: (@escaping () -> Void) -> Content
    ) {
        window?.close()   // replace any existing instance (e.g. a different target)
        let close: () -> Void = { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        let hosting = NSHostingController(rootView: content(close).environment(model))
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// One reusable window per dialog kind.
@MainActor
enum Dialogs {
    static let create = DialogWindow()
    static let restore = DialogWindow()
    static let log = DialogWindow()
    static let settings = DialogWindow()
}
