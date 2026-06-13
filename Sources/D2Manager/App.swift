import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct D2ManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.live()

    var body: some Scene {
        MenuBarExtra("DHIS2", systemImage: model.isBusy ? "shippingbox.circle.fill" : "shippingbox") {
            MenuContentView()
                .environment(model)
                .frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }
}
