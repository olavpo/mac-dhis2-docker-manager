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
    @State private var label = ""
    @State private var timezone = ""
    @State private var corsOrigins = ""             // comma- or space-separated

    private let namePattern = #"^[a-z][a-z0-9_-]{1,29}$"#
    private let memoryPattern = #"^[0-9]+[mMgG]$"#

    private var nameValid: Bool {
        name.range(of: namePattern, options: .regularExpression) != nil
    }

    private var memoryValid: Bool {
        memory.isEmpty || memory.range(of: memoryPattern, options: .regularExpression) != nil
    }

    private var labelValid: Bool { label.count <= 100 }

    private var timezoneValid: Bool {
        timezone.isEmpty || TimeZone.knownTimeZoneIdentifiers.contains(timezone)
    }

    private let originPattern = #"^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?$"#

    private var origins: [String] {
        corsOrigins.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
    }

    private var originsValid: Bool {
        origins.count <= 20 && origins.allSatisfy {
            $0.range(of: originPattern, options: .regularExpression) != nil
        }
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

    private var hasCustomWar: Bool { !warUrl.isEmpty || !warFile.isEmpty }

    /// Doris requires a version with major >= 42, or a custom WAR (whose
    /// version the broker doesn't check; the caller vouches it is 42+).
    private var dorisProblem: String? {
        guard analytics == "doris", !hasCustomWar else { return nil }
        guard let major = versionMajor, major >= 42 else {
            return "Doris requires a version of 42 or later (e.g. 42, 2.42.4), or a custom WAR."
        }
        return nil
    }

    private var formValid: Bool {
        nameValid && memoryValid && portValid(httpPort) && portValid(pgPort) && dorisProblem == nil
            && labelValid && timezoneValid && originsValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New instance").font(.headline)

            TextField("name (lower-case, 2–30 chars)", text: $name)
            if !name.isEmpty && !nameValid {
                Text("Must match ^[a-z][a-z0-9_-]{1,29}$")
                    .font(.caption).foregroundStyle(.red)
            }

            TextField("label (optional, shown in the instance tooltip)", text: $label)
            if !labelValid {
                Text("At most 100 characters.").font(.caption).foregroundStyle(.red)
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
                Text(hasCustomWar
                     ? "Adds a dedicated Apache Doris analytics database (~5.5 GB RAM). The custom WAR must be DHIS2 42 or later; the broker doesn't check."
                     : "Adds a dedicated Apache Doris analytics database (~5.5 GB RAM).")
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
                    TextField("time zone (e.g. Africa/Lagos — blank = UTC)", text: $timezone)
                    if !timezoneValid {
                        Text("Not a known IANA time zone.").font(.caption).foregroundStyle(.red)
                    } else if timezone.isEmpty {
                        Text("Set this to the deployment's zone when testing app sync; DHIS2 checks \"future\" dates against server time.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("extra CORS origins (e.g. http://localhost:4000)", text: $corsOrigins)
                    if !originsValid {
                        Text("Up to 20 origins like http://localhost:4000, separated by commas.")
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
            analytics: analytics.isEmpty ? nil : analytics,
            timezone: timezone.isEmpty ? nil : timezone,
            corsOrigins: origins.isEmpty ? nil : origins,
            label: label.isEmpty ? nil : label
        )
    }
}
