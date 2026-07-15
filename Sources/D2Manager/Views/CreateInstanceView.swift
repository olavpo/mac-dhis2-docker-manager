import SwiftUI

struct CreateInstanceView: View {
    let close: () -> Void
    @Environment(AppModel.self) private var model

    @State private var name = ""
    @State private var version = ""
    @State private var selectedSeed: String? = ""   // "" = no seed
    @State private var tomcat = ""                  // "" = auto (from version)
    @State private var analytics = ""               // "" = default (Postgres), "doris" = Doris
    @State private var showAdvanced = false
    @State private var memory = ""
    @State private var httpPort = ""
    @State private var pgPort = ""
    @State private var warUrl = ""
    @State private var warFile = ""

    private let namePattern = #"^[a-z][a-z0-9_-]{1,29}$"#
    private let memoryPattern = #"^[0-9]+[mMgG]$"#

    private var nameValid: Bool {
        name.range(of: namePattern, options: .regularExpression) != nil
    }

    private var memoryValid: Bool {
        memory.isEmpty || memory.range(of: memoryPattern, options: .regularExpression) != nil
    }

    private func portValid(_ s: String) -> Bool {
        s.isEmpty || (Int(s).map { (1024...65535).contains($0) } ?? false)
    }

    /// DHIS2 major from the version field ("42", "2.42", "2.42.4" → 42).
    private var versionMajor: Int? {
        let parts = version.split(separator: ".")
        guard let first = parts.first, let n = Int(first) else { return nil }
        if n == 2 { return parts.count > 1 ? Int(parts[1]) : nil }
        return n
    }

    /// Doris requires an explicit version with major >= 42 and no custom WAR.
    private var dorisProblem: String? {
        guard analytics == "doris" else { return nil }
        guard let major = versionMajor, major >= 42 else {
            return "Doris requires a version of 42 or later (e.g. 42, 2.42.4)."
        }
        guard warUrl.isEmpty && warFile.isEmpty else {
            return "Doris can't be combined with a custom WAR."
        }
        return nil
    }

    private var formValid: Bool {
        nameValid && memoryValid && portValid(httpPort) && portValid(pgPort) && dorisProblem == nil
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

            VStack(alignment: .leading, spacing: 3) {
                Text("Seed").font(.caption).foregroundStyle(.secondary)
                SeedPicker(seeds: model.seeds, instanceName: nil, includeNoSeed: true, selection: $selectedSeed)
            }

            // Segmented Pickers rather than Toggles: see UpgradeView for the
            // AppKit constraint-reentrancy crash a checkbox triggered here.
            Picker("Tomcat", selection: $tomcat) {
                Text("Auto").tag("")
                Text("10").tag("10")
                Text("9").tag("9")
            }.pickerStyle(.segmented)

            HStack {
                Text("Analytics")
                Spacer()
                Picker("Analytics", selection: $analytics) {
                    Text("Default").tag("")
                    Text("Doris").tag("doris")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if let problem = dorisProblem {
                Text(problem).font(.caption).foregroundStyle(.red)
            } else if analytics == "doris" {
                Text("Adds a dedicated Apache Doris analytics database (~5.5 GB RAM).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("memory — Tomcat max heap (e.g. 2g, 512m — blank = 4g)", text: $memory)
                    if !memoryValid {
                        Text("Must match ^[0-9]+[mMgG]$ (e.g. 512m, 2g)")
                            .font(.caption).foregroundStyle(.red)
                    }
                    HStack {
                        TextField("http_port (blank = auto)", text: $httpPort)
                        TextField("pg_port (blank = auto)", text: $pgPort)
                    }
                    if !portValid(httpPort) || !portValid(pgPort) {
                        Text("Ports must be 1024–65535.")
                            .font(.caption).foregroundStyle(.red)
                    }
                    TextField("war_url (https://…)", text: $warUrl)
                    TextField("war_file (/abs/path.war)", text: $warFile)
                }
                .padding(.top, 4)
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
                .disabled(!formValid)
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
            seed: (selectedSeed ?? "").isEmpty ? nil : selectedSeed,
            tomcat: tomcat.isEmpty ? nil : tomcat,   // nil = broker auto-selects from version
            memory: memory.isEmpty ? nil : memory,
            httpPort: Int(httpPort),
            pgPort: Int(pgPort),
            warUrl: warUrl.isEmpty ? nil : warUrl,
            warFile: warFile.isEmpty ? nil : warFile,
            analytics: analytics.isEmpty ? nil : analytics
        )
    }
}
