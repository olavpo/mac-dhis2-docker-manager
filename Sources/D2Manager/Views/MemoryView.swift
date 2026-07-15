import SwiftUI

struct MemoryView: View {
    let instance: Instance
    let close: () -> Void
    @Environment(AppModel.self) private var model

    @State private var memory = ""

    private let memoryPattern = #"^[0-9]+[mMgG]$"#

    private var valid: Bool {
        memory.range(of: memoryPattern, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set memory for \(instance.name)").font(.headline)
            Text("Sets the Tomcat max heap (-Xmx) and recreates the Tomcat container. The database and volumes are preserved; the instance restarts.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("memory (e.g. 2g, 512m)", text: $memory)
            if !memory.isEmpty && !valid {
                Text("Must match ^[0-9]+[mMgG]$ (e.g. 512m, 2g)")
                    .font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { close() }
                Button("Apply") {
                    Task {
                        await model.setMemory(name: instance.name, memory: memory)
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
