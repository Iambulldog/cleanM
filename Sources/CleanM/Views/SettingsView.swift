import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(UpdateVM.self) private var updates
    @AppStorage("checkForUpdatesAutomatically") private var autoCheck = true
    @AppStorage("deletePermanently") private var deletePermanently = false
    @AppStorage("showCPUInMenuBar") private var showCPU = true
    @State private var hasFDA = PermissionService.hasFullDiskAccess()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CleanM").font(.title2.weight(.bold))
                        Text(AppInfo.versionDescription).font(.callout).foregroundStyle(.secondary)
                        Link("github.com/\(AppInfo.repository)", destination: AppInfo.repositoryURL).font(.caption)
                    }
                }
            }
            Section("Updates") {
                Toggle("Check for updates automatically (once a day)", isOn: $autoCheck)
                HStack {
                    updateStatus
                    Spacer()
                    if updates.availableRelease != nil {
                        Button("Download") { updates.openDownload() }
                        Button("Release Notes") { updates.openReleasePage() }
                    }
                    Button("Check Now") { Task { await updates.check() } }
                        .disabled(updates.status == .checking)
                }
            }
            Section("Cleaning") {
                Toggle("Delete System Junk permanently instead of moving it to the Trash", isOn: $deletePermanently)
                Text("Items in the Trash can be restored. Leave this off unless you are sure.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Menu Bar") {
                Toggle("Show CPU usage next to the menu bar icon", isOn: $showCPU)
            }
            Section("Permissions") {
                HStack {
                    Label(hasFDA ? "Full Disk Access granted" : "Full Disk Access not granted",
                          systemImage: hasFDA ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundStyle(hasFDA ? Theme.lime : Theme.amber)
                    Spacer()
                    Button("Open Privacy Settings") { PermissionService.openFullDiskAccessSettings() }
                    Button("Check") { hasFDA = PermissionService.hasFullDiskAccess() }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.04, green: 0.12, blue: 0.08))
        .frame(width: 520)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updates.status {
        case .idle:
            Text("You're on \(AppInfo.version).").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
        case .upToDate:
            Label("CleanM is up to date.", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.leaf)
        case .available(let release):
            Label("Version \(release.version) is available.", systemImage: "arrow.down.circle.fill").foregroundStyle(Theme.lime)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.amber)
        }
    }
}
