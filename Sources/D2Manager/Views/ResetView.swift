import SwiftUI

struct ResetView: View {
    let instance: Instance
    let close: () -> Void
    @Environment(AppModel.self) private var model
    @State private var selectedSeed: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore \(instance.name)").font(.headline)
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
                Button("Cancel") { close() }
                Button("Restore", role: .destructive) {
                    Task {
                        await model.reset(name: instance.name, seed: selectedSeed)
                        close()
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
