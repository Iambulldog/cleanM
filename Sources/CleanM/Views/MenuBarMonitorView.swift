import AppKit
import SwiftUI

struct MenuBarMonitorView: View {
    @Environment(MonitorVM.self) private var vm
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = vm.stats
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill").foregroundStyle(Theme.scanGradient)
                Text("CleanM").font(.system(.headline, design: .rounded))
                Spacer()
                Text(s.memory.pressure.title + " pressure").font(.caption).foregroundStyle(.secondary)
            }

            bar("CPU", "cpu", s.cpuTotal, "\(Int(s.cpuTotal * 100))%", [Theme.mint, Theme.leaf])
            bar("Memory", "memorychip", s.memory.usedFraction,
                "\(ByteFormat.string(s.memory.used)) / \(ByteFormat.string(s.memory.total))", [Theme.leaf, Theme.moss])
            bar("Disk", "internaldrive", s.disk.usedFraction,
                "\(ByteFormat.string(s.disk.available)) free", [Theme.amber, Theme.moss])

            HStack {
                Label(ByteFormat.rate(s.network.downloadPerSecond), systemImage: "arrow.down")
                Spacer()
                Label(ByteFormat.rate(s.network.uploadPerSecond), systemImage: "arrow.up")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            Sparkline(values: vm.cpuHistory, color: Theme.mint, maxValue: 1).frame(height: 30)

            if let message = vm.purgeMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Button {
                    Task { await vm.freeUpRAM() }
                } label: {
                    Label(vm.isPurging ? "Purging…" : "Free Up RAM", systemImage: "bolt.fill")
                }
                .disabled(vm.isPurging)
                Spacer()
                Button("Open CleanM") {
                    let popover = NSApp.keyWindow
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                    popover?.close()
                }
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("Quit CleanM")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
        .background(LinearGradient(colors: [Color(red: 0.06, green: 0.16, blue: 0.10), Color(red: 0.03, green: 0.10, blue: 0.07)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private func bar(_ title: String, _ symbol: String, _ value: Double, _ detail: String, _ colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: symbol).font(.callout)
                Spacer()
                Text(detail).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * min(1, value)))
                }
            }
            .frame(height: 6)
            .animation(Theme.spring, value: value)
        }
    }
}

struct MenuBarLabel: View {
    @Environment(MonitorVM.self) private var vm
    @AppStorage("showCPUInMenuBar") private var showCPU = true

    var body: some View {
        // MenuBarExtra labels drop mixed Image+Text content, so draw both into one template image.
        Image(nsImage: Self.render(cpu: showCPU ? Int(vm.stats.cpuTotal * 100) : nil))
    }

    @MainActor
    private static func render(cpu: Int?) -> NSImage {
        let content = HStack(spacing: 3) {
            Image(systemName: "leaf.fill").font(.system(size: 13, weight: .semibold))
            if let cpu {
                Text("\(cpu)%").font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
        .foregroundStyle(.black)
        .fixedSize()

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "CleanM") ?? NSImage()
        image.isTemplate = true
        image.accessibilityDescription = cpu.map { "CleanM, CPU \($0)%" } ?? "CleanM"
        return image
    }
}
