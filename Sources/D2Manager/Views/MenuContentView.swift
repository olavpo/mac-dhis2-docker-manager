import SwiftUI

struct MenuContentView: View {
    @Environment(AppModel.self) private var model
    @State private var resetTarget: Instance?
    @State private var deleteTarget: Instance?
    @State private var showCreate = false
    @State private var logJobID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let job = model.activeJob {
                ActiveOperationView(job: job)
            }
            if let error = model.lastError, model.activeJob == nil {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if model.instances.isEmpty {
                Text("No instances.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.instances) { instance in
                            InstanceRowView(
                                instance: instance,
                                isBusy: model.isBusy,
                                onStart: { Task { await model.start(name: instance.name) } },
                                onStop: { Task { await model.stop(name: instance.name) } },
                                onReset: { resetTarget = instance },
                                onDelete: { deleteTarget = instance }
                            )
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            if !model.recentJobs.isEmpty {
                Divider()
                Text("Recent activity").font(.caption).foregroundStyle(.secondary)
                ForEach(model.recentJobs.prefix(5)) { job in
                    HStack {
                        Image(systemName: job.status == .succeeded ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundStyle(job.status == .succeeded ? .green : .red)
                        Text("\(job.op.rawValue.capitalized) \(job.instance)")
                            .font(.caption)
                        Spacer()
                        if job.status != .succeeded {
                            Button("Log") { logJobID = job.id }
                                .controlSize(.mini)
                        }
                    }
                }
            }
            footer
        }
        .padding(12)
        .task {
            await model.refreshAll()
            await model.loadRecentJobs()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await model.refresh()
            }
        }
        .sheet(isPresented: $showCreate) { CreateInstanceView() }
        .sheet(item: $resetTarget) { ResetView(instance: $0) }
        .confirmationDialog(
            "Delete \(deleteTarget?.name ?? "")? This is irreversible.",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            presenting: deleteTarget
        ) { instance in
            Button("Delete \(instance.name)", role: .destructive) {
                Task { await model.delete(name: instance.name) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(get: { logJobID.map { LogID(id: $0) } },
                             set: { logJobID = $0?.id })) { wrapper in
            JobLogView(jobID: wrapper.id)
        }
    }

    private var header: some View {
        HStack {
            Text("DHIS2 Instances").font(.headline)
            Spacer()
            Button { Task { await model.refreshAll() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain)
                .disabled(model.isBusy)
        }
    }

    private var footer: some View {
        HStack {
            Button("New instance…") { showCreate = true }.disabled(model.isBusy)
            Spacer()
            Button("Settings") { openSettings() }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small)
    }

    private func openSettings() {
        SettingsWindow.shared.show(model: model)
    }
}

private struct LogID: Identifiable { let id: String }
