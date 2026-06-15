import SwiftUI

/// The single in-flight operation. A tinted glass banner with a light sweep
/// while the job runs — the app's "something is happening" heartbeat.
struct ActiveOperationView: View {
    let job: Job
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text("\(verb) \(job.instance)…")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            if let tail = job.logTail, !tail.isEmpty {
                Text(tail)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.55)), in: .rect(cornerRadius: 14))
        .overlay {
            if !reduceMotion {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.22), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.45)
                    .offset(x: sweep ? geo.size.width : -geo.size.width * 0.45)
                }
                .allowsHitTesting(false)
            }
        }
        .clipShape(.rect(cornerRadius: 14))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                sweep = true
            }
        }
    }

    /// Present-tense verb for the running op.
    private var verb: String {
        switch job.op {
        case .create: "Creating"
        case .reset: "Restoring"
        case .start: "Starting"
        case .stop: "Stopping"
        case .delete: "Deleting"
        case .backup: "Backing up"
        case .upgrade: "Upgrading"
        }
    }
}
