import SwiftUI

struct ResetView: View {
    let instance: Instance
    let close: () -> Void
    @Environment(AppModel.self) private var model
    @State private var selectedSeed: String?

    private var canRestore: Bool { !(selectedSeed ?? "").isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore \(instance.name)").font(.headline)
            Text("Restores the database from a seed or backup. Existing data is replaced.")
                .font(.caption).foregroundStyle(.secondary)

            SeedPicker(seeds: model.seeds, instanceName: instance.name, selection: $selectedSeed)

            HStack {
                Spacer()
                Button("Cancel") { close() }
                Button("Restore", role: .destructive) {
                    guard let seed = selectedSeed, !seed.isEmpty else { return }
                    Task {
                        await model.reset(name: instance.name, seed: seed)
                        close()
                    }
                }
                .disabled(!canRestore)
            }
        }
        .padding(16)
        .frame(width: 440)
        .task { await model.loadSeeds() }
    }
}
