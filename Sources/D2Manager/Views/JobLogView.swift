import SwiftUI

struct JobLogView: View {
    let jobID: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var log = "Loading…"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log — \(jobID)").font(.headline)
            ScrollView {
                Text(log)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack { Spacer(); Button("Close") { dismiss() } }
        }
        .padding(16)
        .frame(width: 520, height: 360)
        .task { log = await model.fullLog(for: jobID) }
    }
}
