import SwiftUI

struct ResetView: View {
    let instance: Instance
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeed: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset \(instance.name)").font(.headline)
            Text("Restores the database from a seed. Existing data is replaced.")
                .font(.caption).foregroundStyle(.secondary)

            Picker("Seed", selection: $selectedSeed) {
                Text("Choose a seed…").tag("")
                ForEach(model.seeds) { seed in
                    Text(seed.path).tag(seed.path)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Reset", role: .destructive) {
                    Task {
                        await model.reset(name: instance.name, seed: selectedSeed)
                        dismiss()
                    }
                }
                .disabled(selectedSeed.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360)
        .task { await model.loadSeeds() }
    }
}
