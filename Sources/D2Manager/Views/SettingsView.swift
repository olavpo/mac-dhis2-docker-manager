import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var baseURLString = Settings.load(from: .standard).baseURL.absoluteString
    @State private var dhis2BasePath = Settings.load(from: .standard).dhis2BasePath ?? ""
    @State private var tokenOverride = Settings.load(from: .standard).tokenOverride ?? ""
    @State private var testResult = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginNote = LaunchAtLogin.note(for: SMAppService.mainApp.status)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)
            Form {
                TextField("Broker base URL", text: $baseURLString)
                TextField("DHIS2_BASE path (for tokens.json)", text: $dhis2BasePath)
                SecureField("Admin token override (optional)", text: $tokenOverride)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if !launchAtLoginNote.isEmpty {
                    Text(launchAtLoginNote).font(.caption).foregroundStyle(.secondary)
                }
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

    /// Applied immediately (it is system state, not an app preference).
    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        // Ignore the onChange fired by re-syncing the switch below.
        guard enabled != (service.status == .enabled) else { return }
        do {
            if enabled { try service.register() } else { try service.unregister() }
            launchAtLoginNote = LaunchAtLogin.note(for: service.status)
        } catch {
            launchAtLoginNote = "Could not update login item: \(error.localizedDescription)"
        }
        // Re-sync the switch if registration failed or needs approval.
        if launchAtLogin != (service.status == .enabled) {
            launchAtLogin = service.status == .enabled
        }
    }

    private func save() {
        var settings = Settings()
        if let url = URL(string: baseURLString) { settings.baseURL = url }
        settings.dhis2BasePath = dhis2BasePath.isEmpty ? nil : dhis2BasePath
        settings.tokenOverride = tokenOverride.isEmpty ? nil : tokenOverride
        model.persist(settings: settings)
    }
}

private enum LaunchAtLogin {
    static func note(for status: SMAppService.Status) -> String {
        switch status {
        case .requiresApproval:
            return "Allow D2Manager in System Settings › General › Login Items."
        case .notFound:
            return "Install D2Manager.app in /Applications to launch at login."
        default:
            return ""
        }
    }
}
