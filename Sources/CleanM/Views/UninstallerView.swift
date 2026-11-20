import AppKit
import SwiftUI

struct UninstallerView: View {
    @Environment(UninstallerVM.self) private var vm
    @State private var confirm = false

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(module: .uninstaller, subtitle: "Remove apps completely, including their support files.")
            HStack(alignment: .top, spacing: 16) {
                appList(search: $vm.searchText, selection: $vm.selectedAppID)
                    .frame(width: 320)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24)
        .task { if vm.apps.isEmpty { await vm.load() } }
        .confirmationDialog("Uninstall \(vm.selectedApp?.name ?? "")?", isPresented: $confirm) {
            Button("Move to Trash", role: .destructive) { Task { await vm.uninstallSelected() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app and \(vm.leftovers.filter(\.isSelected).count) selected support items will be moved to the Trash.")
        }
    }

    private func appList(search: Binding<String>, selection: Binding<InstalledApp.ID?>) -> some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search apps", text: search).textFieldStyle(.plain)
                    if vm.isLoading { ProgressView().controlSize(.small) }
                    Button { Task { await vm.load() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain)
                        .help("Reload")
                }
                .padding(12)
                Divider().opacity(0.4)
                List(vm.filteredApps, selection: selection) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon).resizable().frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name).lineLimit(1)
                            Text(app.version.map { "v\($0)" } ?? "—")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if app.isSystemApp {
                            Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(ByteFormat.string(app.size)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(app.id)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let app = vm.selectedApp {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        Image(nsImage: app.icon).resizable().frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name).font(.system(.title, design: .rounded).weight(.bold))
                            Text([app.version.map { "Version \($0)" }, app.bundleID].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            Text(app.url.path).font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Total").font(.caption).foregroundStyle(.secondary)
                            Text(ByteFormat.string(app.size + vm.selectedLeftoverSize))
                                .font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
                        }
                    }

                    if app.isSystemApp {
                        warning("lock.shield", "This is a macOS system app and can't be uninstalled.", .secondary)
                    } else if vm.isRunning(app) {
                        warning("exclamationmark.triangle.fill", "\(app.name) is running. Quit it before uninstalling.", Theme.amber)
                    }

                    if let result = vm.lastResult { ResultBanner(result: result) }

                    Text("Application & Support Files").font(.headline)
                    ScrollView {
                        VStack(spacing: 0) {
                            row(icon: Image(nsImage: app.icon), title: app.url.lastPathComponent,
                                subtitle: app.url.path, group: "Application", size: app.size,
                                state: true, action: nil)
                            if vm.isLoadingLeftovers {
                                ProgressView().padding()
                            }
                            ForEach(vm.leftovers) { item in
                                row(icon: Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)),
                                    title: item.url.lastPathComponent, subtitle: item.displayPath,
                                    group: item.group, size: item.size, state: item.isSelected) {
                                    vm.toggleLeftover(item.id)
                                }
                            }
                            if !vm.isLoadingLeftovers && vm.leftovers.isEmpty {
                                Text("No leftover files found.").font(.caption).foregroundStyle(.secondary).padding()
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            confirm = true
                        } label: {
                            if vm.isUninstalling { ProgressView().controlSize(.small).frame(width: 80) } else { Text("Uninstall") }
                        }
                        .buttonStyle(PillButtonStyle(colors: [Theme.leaf, Theme.moss]))
                        .disabled(app.isSystemApp || vm.isRunning(app) || vm.isUninstalling)
                    }
                }
            }
        } else if let result = vm.lastResult {
            VStack { ResultBanner(result: result); Spacer() }
        } else {
            GlassCard {
                EmptyStateView(symbol: "square.grid.3x3.square", title: "Select an app",
                               message: "Choose an app on the left to see its size and leftover files.")
            }
        }
    }

    private func warning(_ symbol: String, _ text: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(color)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(icon: Image, title: String, subtitle: String, group: String, size: Int64,
                     state: Bool, action: (() -> Void)?) -> some View {
        HStack(spacing: 10) {
            if let action {
                CheckBox(state: state, tint: Theme.lime, action: action)
            } else {
                Image(systemName: "checkmark.square.fill").foregroundStyle(Theme.lime.opacity(0.5))
            }
            icon.resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout).lineLimit(1)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(group).font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.white.opacity(0.08), in: Capsule())
            Text(ByteFormat.string(size)).font(.caption).monospacedDigit().frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 5)
    }
}
