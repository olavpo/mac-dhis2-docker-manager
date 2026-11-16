import SwiftUI

struct AnalyticsView: View {
    let instance: Instance
    let close: () -> Void
    @Environment(AppModel.self) private var model

    @State private var lastYears = ""

    private var years: Int? { Int(lastYears) }

    private var valid: Bool {
        lastYears.isEmpty || (years.map { (1...50).contains($0) } ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run analytics on \(instance.name)").font(.headline)
            Text("Generates the analytics tables and waits for DHIS2 to report completion. Other jobs queue behind it.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("last years (1–50, blank = all years)", text: $lastYears)
            if !valid {
                Text("Must be a whole number from 1 to 50.")
                    .font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { close() }
                Button("Run") {
                    Task {
                        await model.runAnalytics(name: instance.name, lastYears: years)
                        close()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!valid)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}
