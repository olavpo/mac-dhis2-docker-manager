import SwiftUI

struct InstanceRowView: View {
    let instance: Instance
    let isBusy: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    private var pillColor: Color {
        switch instance.status {
        case .running: return .green
        case .partial: return .orange
        case .stopped: return .gray
        }
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
                if let urlString = instance.localhostUrl, let url = URL(string: urlString) {
                    Link(destination: url) { Image(systemName: "safari") }
                        .help("Open \(urlString)")
                }
            }
            HStack(spacing: 8) {
                if instance.status == .stopped {
                    Button("Start", action: onStart)
                } else {
                    Button("Stop", action: onStop)
                }
                Button("Reset", action: onReset)
                Button("Delete", role: .destructive, action: onDelete)
            }
            .controlSize(.small)
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }
}
