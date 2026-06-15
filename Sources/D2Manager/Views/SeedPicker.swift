import SwiftUI

/// A searchable, sectioned seed chooser. When `instanceName` is set, that
/// instance's own backups are surfaced in their own section first — the most
/// likely thing to restore.
struct SeedPicker: View {
    let seeds: [Seed]
    let instanceName: String?
    var includeNoSeed = false
    @Binding var selection: String?

    @State private var search = ""

    private var matches: [Seed] {
        guard !search.isEmpty else { return seeds }
        return seeds.filter { $0.path.localizedCaseInsensitiveContains(search) }
    }
    private var ownBackupPrefix: String? { instanceName.map { "backups/\($0)/" } }
    private var ownBackups: [Seed] {
        guard let p = ownBackupPrefix else { return [] }
        return matches.filter { $0.source == .backups && $0.path.hasPrefix(p) }
    }
    private var curated: [Seed] { matches.filter { $0.source == .seeds } }
    private var otherBackups: [Seed] {
        matches.filter { seed in
            guard seed.source == .backups else { return false }
            if let p = ownBackupPrefix { return !seed.path.hasPrefix(p) }
            return true   // no instance context → every backup lands here
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search seeds & backups…", text: $search)
                .textFieldStyle(.roundedBorder)

            List(selection: $selection) {
                if includeNoSeed && search.isEmpty {
                    Label("No seed (empty database)", systemImage: "doc")
                        .tag("")
                }
                if let name = instanceName, !ownBackups.isEmpty {
                    Section("Backups of \(name)") {
                        ForEach(ownBackups) { row($0) }
                    }
                }
                if !curated.isEmpty {
                    Section("Seeds") { ForEach(curated) { row($0) } }
                }
                if !otherBackups.isEmpty {
                    Section(instanceName == nil ? "Backups" : "Other backups") {
                        ForEach(otherBackups) { row($0) }
                    }
                }
            }
            .frame(minHeight: 220, maxHeight: 320)

            if matches.isEmpty && !seeds.isEmpty {
                Text("No seeds match “\(search)”.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func row(_ seed: Seed) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(displayName(seed.path)).lineLimit(1).truncationMode(.middle)
            Text(subtitle(seed)).font(.caption2).foregroundStyle(.secondary)
        }
        .tag(seed.path)
    }

    private func displayName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    private func subtitle(_ seed: Seed) -> String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(seed.sizeBytes), countStyle: .file)
        let date = String(seed.modified.prefix(10))   // YYYY-MM-DD
        return "\(size) · \(date)"
    }
}
