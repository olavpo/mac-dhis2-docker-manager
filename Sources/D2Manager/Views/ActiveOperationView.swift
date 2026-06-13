import SwiftUI

struct ActiveOperationView: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("\(job.op.rawValue.capitalized) \(job.instance)…")
                    .font(.subheadline).bold()
            }
            if let tail = job.logTail, !tail.isEmpty {
                Text(tail)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
