import SwiftUI

struct InstanceRowView: View {
    let instance: Instance
    let isBusy: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestore: () -> Void
    let onBackup: () -> Void
    let onUpgrade: () -> Void
    let onSetMemory: () -> Void
    let onRunAnalytics: () -> Void
    let onDelete: () -> Void

    private var url: URL? {
        instance.localhostUrl.flatMap(URL.init(string:))
    }

    /// Tooltip on the name: label and time zone from create, when set.
    private var nameHelp: String {
        var lines = [instance.name]
        if let label = instance.label, !label.isEmpty { lines.append(label) }
        if let tz = instance.timezone { lines.append("Time zone: \(tz)") }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: instance.status)

            Text(instance.name)
                .font(Theme.rowName)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(nameHelp)

            if instance.agentManaged {
                Text("agent")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .glassEffect(.regular, in: .capsule)
            }
            if instance.analytics == "doris" {
                Text("doris")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .glassEffect(.regular, in: .capsule)
                    .help("Dedicated Apache Doris analytics database")
            }
            if let readiness = instance.readiness, readiness != "ready" {
                Text(readiness)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15), in: .capsule)
                    .help(readiness == "migrating"
                          ? "DHIS2 is answering but still starting up (Flyway migrations or context startup)."
                          : "Tomcat is up but DHIS2 isn't answering on /api yet.")
            }
            if let v = instance.dhis2MajorVersion {
                Text("v\(v)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
                    .help("DHIS2 \(v)")
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if instance.status == .stopped {
                    Button(action: onStart) { Label("Start", systemImage: "play.fill") }
                        .tint(Theme.color(.running)).help("Start")
                } else {
                    Button(action: onStop) { Label("Stop", systemImage: "stop.fill") }
                        .help("Stop")
                }
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                    .tint(.red).help("Delete")
                moreMenu
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(isBusy)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }

    private var moreMenu: some View {
        Menu {
            if let url {
                Link(destination: url) { Label("Open in Browser", systemImage: "safari") }
            }
            Section {
                Button { onRestore() } label: { Label("Restore DB…", systemImage: "arrow.counterclockwise") }
                Button { onBackup() } label: { Label("Backup DB", systemImage: "tray.and.arrow.down") }
                    .disabled(instance.status != .running)   // the DB must be running to dump
                Button { onUpgrade() } label: { Label("Upgrade / Deploy WAR…", systemImage: "arrow.up.circle") }
                Button { onSetMemory() } label: { Label("Set Memory…", systemImage: "memorychip") }
                Button { onRunAnalytics() } label: { Label("Run Analytics…", systemImage: "chart.bar") }
                    .disabled(instance.status != .running)
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
