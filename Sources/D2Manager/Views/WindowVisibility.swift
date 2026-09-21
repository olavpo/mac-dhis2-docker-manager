import SwiftUI
import AppKit

extension EnvironmentValues {
    /// Whether the window hosting this view is currently drawn on screen.
    ///
    /// `MenuBarExtra(.window)` does not tear the popover down when it closes: the
    /// window is ordered out but its SwiftUI view graph stays alive, and
    /// `onDisappear` never fires. Any `repeatForever` animation left running in
    /// it forces a layout + render pass on every display frame — measured at
    /// ~20% CPU, indefinitely, on a ProMotion display. Views that run indefinite
    /// animations must therefore stop them (ideally by removing the animated
    /// view) whenever this is `false`.
    @Entry var windowIsVisible: Bool = true
}

extension View {
    /// Observe the hosting window's occlusion state and publish it to the subtree
    /// as `windowIsVisible`. Attach once, at the root of the popover content.
    func trackingWindowVisibility() -> some View {
        modifier(WindowVisibilityModifier())
    }
}

private struct WindowVisibilityModifier: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .background(WindowVisibilityObserver(isVisible: $isVisible))
            .environment(\.windowIsVisible, isVisible)
    }
}

/// Zero-size AppKit view that watches its window's occlusion state. The state
/// loses `.visible` when the window is ordered out, which is what the closed
/// MenuBarExtra popover does.
private struct WindowVisibilityObserver: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> ObserverView { ObserverView() }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onChange = { isVisible = $0 }
    }

    final class ObserverView: NSView {
        var onChange: ((Bool) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let center = NotificationCenter.default
            center.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
            guard let window else { publish(false); return }
            center.addObserver(
                self, selector: #selector(occlusionChanged),
                name: NSWindow.didChangeOcclusionStateNotification, object: window
            )
            publish(window.occlusionState.contains(.visible))
        }

        @objc private func occlusionChanged(_ note: Notification) {
            guard let window else { return }
            publish(window.occlusionState.contains(.visible))
        }

        private func publish(_ visible: Bool) {
            // viewDidMoveToWindow can run mid-layout; SwiftUI rejects state writes
            // during a view update, so hop to the next run-loop turn.
            DispatchQueue.main.async { [weak self] in self?.onChange?(visible) }
        }
    }
}
