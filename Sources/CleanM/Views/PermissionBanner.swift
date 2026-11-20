import AppKit
import SwiftUI

struct PermissionBanner: View {
    @State private var hasAccess = PermissionService.hasFullDiskAccess()
    @State private var dismissed = false

    var body: some View {
        Group {
            if !hasAccess && !dismissed {
                GlassCard(padding: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Full Disk Access is off").font(.callout.weight(.semibold))
                            Text("Some caches and app data can't be measured. Add CleanM in Privacy & Security → Full Disk Access, then relaunch.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Open Settings") { PermissionService.openFullDiskAccessSettings() }
                            .buttonStyle(PillButtonStyle(colors: [Theme.amber, Theme.moss]))
                        Button {
                            withAnimation(Theme.spring) { dismissed = true }
                        } label: {
                            Image(systemName: "xmark").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Hide until next launch")
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            withAnimation(Theme.spring) { hasAccess = PermissionService.hasFullDiskAccess() }
        }
    }
}
