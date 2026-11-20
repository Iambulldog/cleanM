import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (e.g. `swift run`) rather than from the .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // keep the menu bar monitor alive
    }
}

@main
struct CleanMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var smartScan = SmartScanVM()
    @State private var junk = JunkVM()
    @State private var largeFiles = LargeFilesVM()
    @State private var uninstaller = UninstallerVM()
    @State private var updates = UpdateVM()
    @State private var monitor: MonitorVM = {
        let vm = MonitorVM()
        vm.start()
        return vm
    }()

    var body: some Scene {
        Window("CleanM", id: "main") {
            RootView()
                .environment(smartScan)
                .environment(junk)
                .environment(largeFiles)
                .environment(uninstaller)
                .environment(monitor)
                .environment(updates)
                .preferredColorScheme(.dark)
                .task { updates.checkOnLaunchIfNeeded() }
        }
        .defaultSize(width: 1120, height: 720)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Task { await updates.check() } }
            }
        }

        MenuBarExtra {
            MenuBarMonitorView()
                .environment(monitor)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarLabel().environment(monitor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(updates)
                .preferredColorScheme(.dark)
        }
    }
}
