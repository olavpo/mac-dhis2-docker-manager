import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var baseURLString = Settings.load(from: .standard).baseURL.absoluteString
    @State private var dhis2BasePath = Settings.load(from: .standard).dhis2BasePath ?? ""
    @State private var tokenOverride = Settings.load(from: .standard).tokenOverride ?? ""
    @State private var testResult = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)
            Form {
                TextField("Broker base URL", text: $baseURLString)
                TextField("DHIS2_BASE path (for tokens.json)", text: $dhis2BasePath)
                SecureField("Admin token override (optional)", text: $tokenOverride)
            }
            HStack {
                Button("Test connection") {
                    Task {
                        guard let url = URL(string: baseURLString) else { testResult = "Invalid URL."; return }
                        testResult = await model.testConnection(
                            baseURL: url, dhis2BasePath: dhis2BasePath, tokenOverride: tokenOverride)
                    }
                }
                Text(testResult).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
            Text("Changes apply after relaunch.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 420)
    }

    private func save() {
        var settings = Settings()
        if let url = URL(string: baseURLString) { settings.baseURL = url }
        settings.dhis2BasePath = dhis2BasePath.isEmpty ? nil : dhis2BasePath
        settings.tokenOverride = tokenOverride.isEmpty ? nil : tokenOverride
        model.persist(settings: settings)
    }
}

/// Hosts SettingsView in a standalone NSWindow (MenuBarExtra popovers can't push
/// a separate Settings scene cleanly in an accessory app).
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView().environment(model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "D2 Manager Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
