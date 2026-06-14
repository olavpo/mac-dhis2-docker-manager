import SwiftUI
import AppKit

struct MenuContentView: View {
    @Environment(AppModel.self) private var model

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
                                onRestore: { openRestore(instance) },
                                onDelete: { confirmDelete(instance) }
                            )
                            Divider()
                        }
                    }
                }
                // A ScrollView has no intrinsic content height, so in the
                // auto-sizing menu-bar window it collapses to ~one row unless given
                // a minimum. minHeight keeps several instances visible; maxHeight
                // caps it so a long list scrolls instead of growing without bound.
                .frame(minHeight: 200, maxHeight: 320)
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
                            Button("Log") { openLog(job) }
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
                if Task.isCancelled { break }
                await model.refresh()
            }
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
            Button("New instance…") { openCreate() }.disabled(model.isBusy)
            Spacer()
            Button("Settings") { openSettings() }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small)
    }

    // MARK: Dialog windows
    //
    // These open standalone NSWindows (not .sheets on the MenuBarExtra popover),
    // because the transient popover dismisses when a child control such as a
    // Picker dropdown takes focus — which would take an attached sheet with it.

    private func openCreate() {
        Dialogs.create.present(title: "New instance", model: model) { close in
            CreateInstanceView(close: close)
        }
    }

    private func openRestore(_ instance: Instance) {
        Dialogs.restore.present(title: "Restore \(instance.name)", model: model) { close in
            ResetView(instance: instance, close: close)
        }
    }

    private func openLog(_ job: Job) {
        Dialogs.log.present(title: "Log — \(job.id)", model: model) { close in
            JobLogView(jobID: job.id, close: close)
        }
    }

    private func openSettings() {
        Dialogs.settings.present(title: "D2 Manager Settings", model: model) { _ in
            SettingsView()
        }
    }

    private func confirmDelete(_ instance: Instance) {
        let alert = NSAlert()
        alert.messageText = "Delete \(instance.name)?"
        alert.informativeText = "This permanently removes the instance, its containers, and volumes. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            Task { await model.delete(name: instance.name) }
        }
    }
}
