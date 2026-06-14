import SwiftUI

struct CreateInstanceView: View {
    let close: () -> Void
    @Environment(AppModel.self) private var model

    @State private var name = ""
    @State private var version = ""
    @State private var selectedSeed: String = ""   // "" = no seed
    @State private var tomcat = "10"
    @State private var showAdvanced = false
    @State private var warUrl = ""
    @State private var warFile = ""

    private let namePattern = #"^[a-z][a-z0-9_-]{1,29}$"#

    private var nameValid: Bool {
        name.range(of: namePattern, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New instance").font(.headline)

            TextField("name (lower-case, 2–30 chars)", text: $name)
            if !name.isEmpty && !nameValid {
                Text("Must match ^[a-z][a-z0-9_-]{1,29}$")
                    .font(.caption).foregroundStyle(.red)
            }

            TextField("version (e.g. 42, 2.42, 2.42.4 — blank = latest)", text: $version)

            Picker("Seed", selection: $selectedSeed) {
                Text("No seed (empty database)").tag("")
                ForEach(model.seeds) { seed in
                    Text(seed.path).tag(seed.path)
                }
            }

            Picker("Tomcat", selection: $tomcat) {
                Text("10").tag("10")
                Text("9").tag("9")
            }.pickerStyle(.segmented)

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                TextField("war_url (https://…)", text: $warUrl)
                TextField("war_file (/abs/path.war)", text: $warFile)
            }

            HStack {
                Spacer()
                Button("Cancel") { close() }
                Button("Create") {
                    Task {
                        await model.create(makeRequest())
                        close()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!nameValid)
            }
        }
        .padding(16)
        .frame(width: 380)
        .task { await model.loadSeeds() }
    }

    private func makeRequest() -> CreateInstanceRequest {
        CreateInstanceRequest(
            name: name,
            version: version.isEmpty ? nil : version,
            seed: selectedSeed.isEmpty ? nil : selectedSeed,
            tomcat: tomcat,
            warUrl: warUrl.isEmpty ? nil : warUrl,
            warFile: warFile.isEmpty ? nil : warFile
        )
    }
}
