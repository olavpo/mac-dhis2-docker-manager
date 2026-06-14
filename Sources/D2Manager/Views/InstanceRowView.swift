import SwiftUI

struct InstanceRowView: View {
    let instance: Instance
    let isBusy: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    private var pillColor: Color {
        switch instance.status {
        case .running: return .green
        case .partial: return .orange
        case .stopped: return .gray
        }
    }

    private var url: URL? {
        instance.localhostUrl.flatMap(URL.init(string:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(pillColor).frame(width: 8, height: 8)
                Text(instance.name).bold()
                if instance.agentManaged {
                    Text("agent").font(.caption2).padding(.horizontal, 4)
                        .background(.tertiary, in: Capsule())
                }
                if let v = instance.dhis2MajorVersion {
                    Text("v\(v)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                if instance.status == .stopped {
                    Button("Start", action: onStart)
                } else {
                    Button("Stop", action: onStop)
                }
                Button("Delete", role: .destructive, action: onDelete)
                Spacer()
                moreMenu
            }
            .controlSize(.small)
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }

    private var moreMenu: some View {
        Menu {
            if let url {
                Link(destination: url) { Label("Open in Browser", systemImage: "safari") }
            }
            Button { onRestore() } label: { Label("Restore DB…", systemImage: "arrow.counterclockwise") }
            // Not yet exposed by the d2-broker API — placeholders until the broker
            // gains backup and deploy-to-existing-instance endpoints.
            Section("Requires broker support") {
                Button { } label: { Label("Backup DB", systemImage: "tray.and.arrow.down") }
                    .disabled(true)
                Button { } label: { Label("Deploy WAR…", systemImage: "shippingbox.and.arrow.backward") }
                    .disabled(true)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
