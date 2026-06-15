import SwiftUI

struct UpgradeView: View {
    let instance: Instance
    let close: () -> Void
    @Environment(AppModel.self) private var model

    @State private var version = ""
    @State private var showAdvanced = false
    @State private var warUrl = ""
    @State private var warFile = ""
    @State private var backupFirst = true

    /// The broker requires exactly one of version / war_url / war_file.
    private var sourceCount: Int {
        [version, warUrl, warFile].filter { !$0.isEmpty }.count
    }
    private var valid: Bool { sourceCount == 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upgrade \(instance.name)").font(.headline)
            Text("Swaps the running WAR (version bump or a specific WAR). The database and volumes are preserved; Flyway migrates on next boot.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("version (e.g. 2.42, 2.42.4)", text: $version)

            DisclosureGroup("Advanced (custom WAR)", isExpanded: $showAdvanced) {
                TextField("war_url (https://…)", text: $warUrl)
                TextField("war_file (/abs/path.war)", text: $warFile)
            }

            // A segmented Picker rather than a Toggle: a baseline-aligned checkbox
            // here triggered an AppKit constraint-reentrancy crash when the window
            // opened over the animated popover.
            HStack {
                Text("Back up database first")
                Spacer()
                Picker("Back up database first", selection: $backupFirst) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            if sourceCount > 1 {
                Text("Provide exactly one of version / war_url / war_file.")
                    .font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { close() }
                Button("Upgrade") {
                    Task {
                        await model.upgrade(name: instance.name, makeRequest())
                        close()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!valid)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func makeRequest() -> UpgradeRequest {
        UpgradeRequest(
            version: version.isEmpty ? nil : version,
            warUrl: warUrl.isEmpty ? nil : warUrl,
            warFile: warFile.isEmpty ? nil : warFile,
            backupFirst: backupFirst
        )
    }
}
