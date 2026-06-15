import SwiftUI
import AppKit

struct MenuContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("showRecentActivity") private var showRecentActivity = false
    @State private var refreshTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let job = model.activeJob {
                ActiveOperationView(job: job)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(.red.opacity(0.3)), in: .rect(cornerRadius: 12))
                    .transition(.opacity)
            }

            instanceList

            if !model.recentJobs.isEmpty { recentActivity }

            footer
        }
        .padding(14)
        .tint(Theme.accent)
        .animation(.smooth(duration: 0.3), value: model.activeJob)
        .animation(.smooth(duration: 0.35), value: model.instances)
        .animation(.smooth(duration: 0.3), value: model.lastError)
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

    // MARK: Sections

    @ViewBuilder private var instanceList: some View {
        if model.instances.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 26)).foregroundStyle(.secondary)
                Text("No instances yet").font(Theme.rowName)
                Text("Create one to get started.").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(model.instances) { instance in
                        InstanceRowView(
                            instance: instance,
                            isBusy: model.isBusy,
                            onStart: { Task { await model.start(name: instance.name) } },
                            onStop: { Task { await model.stop(name: instance.name) } },
                            onRestore: { openRestore(instance) },
                            onBackup: { Task { await model.backup(name: instance.name) } },
                            onUpgrade: { openUpgrade(instance) },
                            onDelete: { confirmDelete(instance) }
                        )
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(.trailing, 14)   // keep the ⋯ button clear of the scroll bar
            }
            // A ScrollView has no intrinsic content height; in the auto-sizing
            // menu-bar window it collapses without a minimum. minHeight keeps
            // several rows visible; maxHeight scrolls a long (10+) list.
            .frame(minHeight: 240, maxHeight: 480)
        }
    }

    private var recentActivity: some View {
        DisclosureGroup(isExpanded: $showRecentActivity) {
            VStack(spacing: 3) {
                ForEach(model.recentJobs.prefix(8)) { job in
                    HStack(spacing: 7) {
                        Image(systemName: job.status == .succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(job.status == .succeeded ? Theme.color(.running) : .red)
                        Text("\(job.op.rawValue.capitalized) \(job.instance)").font(.caption)
                        Spacer()
                        if job.status != .succeeded {
                            Button("Log") { openLog(job) }.controlSize(.mini)
                        }
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            Text("Recent activity (\(model.recentJobs.count))")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("DHIS2 Instances").font(Theme.title)
                Text(summary).font(.caption2).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.6)) { refreshTick += 1 }
                Task { await model.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(Double(refreshTick) * 360))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(model.isBusy)
        }
    }

    private var summary: String {
        let total = model.instances.count
        guard total > 0 else { return "No instances" }
        let running = model.instances.filter { $0.status == .running }.count
        return "\(running) running · \(total) total"
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { openCreate() } label: { Label("New instance", systemImage: "plus") }
                .tint(Theme.accent)
                .disabled(model.isBusy)
            Spacer()
            Button { openSettings() } label: { Image(systemName: "gearshape") }
            Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
        }
        .buttonStyle(.glass)
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

    private func openUpgrade(_ instance: Instance) {
        Dialogs.upgrade.present(title: "Upgrade \(instance.name)", model: model) { close in
            UpgradeView(instance: instance, close: close)
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
        // Raise above the MenuBarExtra popover so the alert isn't hidden behind it.
        alert.window.level = .popUpMenu
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Task { await model.delete(name: instance.name) }
        }
    }
}
