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
        @ViewBuilder content: @escaping (@escaping () -> Void) -> Content
    ) {
        // Defer to the next run-loop turn. When invoked from a SwiftUI `Menu`
        // (the ⋯ menu), we're inside AppKit's modal menu-tracking loop;
        // creating/ordering a window synchronously there re-enters the window
        // constraint-update cycle and can crash AppKit layout. Presenting next
        // tick lets menu tracking unwind first.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.show(title: title, model: model, content: content) }
        }
    }

    private func show<Content: View>(
        title: String,
        model: AppModel,
        @ViewBuilder content: (@escaping () -> Void) -> Content
    ) {
        window?.close()   // replace any existing instance (e.g. a different target)
        let close: () -> Void = { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        let hosting = NSHostingController(rootView: content(close).environment(model).tint(Theme.accent))
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        // The MenuBarExtra popover floats above normal windows, so a plain dialog
        // opens behind it. Sit above the popover while focused, then drop back to
        // a normal level once the dialog loses focus so it doesn't float over
        // unrelated apps.
        window.level = .popUpMenu
        window.delegate = WindowLevelDemoter.shared
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Keeps a dialog above the menu-bar popover while focused, then drops it to a
/// normal level on resign so it doesn't float over unrelated apps.
@MainActor
final class WindowLevelDemoter: NSObject, NSWindowDelegate {
    static let shared = WindowLevelDemoter()
    func windowDidBecomeKey(_ notification: Notification) {
        (notification.object as? NSWindow)?.level = .popUpMenu
    }
    func windowDidResignKey(_ notification: Notification) {
        (notification.object as? NSWindow)?.level = .normal
    }
}

/// One reusable window per dialog kind.
@MainActor
enum Dialogs {
    static let create = DialogWindow()
    static let restore = DialogWindow()
    static let upgrade = DialogWindow()
    static let memory = DialogWindow()
    static let log = DialogWindow()
    static let settings = DialogWindow()
}
