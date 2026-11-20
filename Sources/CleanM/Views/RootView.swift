import SwiftUI

struct RootView: View {
    @State private var selection: Module? = .smartScan
    @Environment(SmartScanVM.self) private var smartScan
    @Environment(LargeFilesVM.self) private var largeFiles

    var body: some View {
        let module = selection ?? .smartScan
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
                .frame(width: 220)
            Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
            ZStack {
                GradientBackground(colors: module.colors)
                    .id(module)
                    .transition(.opacity)
                VStack(spacing: 0) {
                    PermissionBanner().padding([.horizontal, .top], 20)
                    detail(for: module)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: selection)
        }
        .ignoresSafeArea()
        .frame(minWidth: 980, minHeight: 660)
        .navigationTitle(module.title)
    }

    @ViewBuilder
    private func detail(for module: Module) -> some View {
        switch module {
        case .smartScan: SmartScanView {
            largeFiles.adopt(smartScan.largeFiles)
            selection = .largeFiles
        }
        case .junk: JunkView()
        case .largeFiles: LargeFilesView()
        case .uninstaller: UninstallerView()
        case .monitor: MonitorView()
        }
    }
}

private struct SidebarView: View {
    @Binding var selection: Module?
    @State private var hovered: Module?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").foregroundStyle(Theme.scanGradient)
                Text("CleanM").font(.system(.title3, design: .rounded).weight(.bold))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)

            ForEach(Module.allCases) { module in
                let isSelected = (selection ?? .smartScan) == module
                Button {
                    selection = module
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: module.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : module.accent)
                            .frame(width: 22)
                        Text(module.title)
                            .font(.system(.body, design: .rounded).weight(isSelected ? .semibold : .regular))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected
                                  ? AnyShapeStyle(LinearGradient(colors: [Theme.leaf.opacity(0.85), Theme.moss.opacity(0.85)],
                                                                 startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.white.opacity(hovered == module ? 0.08 : 0)))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? module : (hovered == module ? nil : hovered) }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
            UpdateBadge()
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            Text("v\(AppInfo.version)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.top, 48) // room for the window's traffic-light buttons
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.08), Color(red: 0.03, green: 0.09, blue: 0.07)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .animation(Theme.spring, value: selection)
    }
}

private struct UpdateBadge: View {
    @Environment(UpdateVM.self) private var updates

    var body: some View {
        if let release = updates.availableRelease {
            Button {
                updates.openDownload()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(Theme.lime)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Update available").font(.caption.weight(.semibold))
                        Text("\(release.version) — click to download").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Theme.leaf.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
