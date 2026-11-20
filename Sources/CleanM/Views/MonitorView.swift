import SwiftUI

struct MonitorView: View {
    @Environment(MonitorVM.self) private var vm

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModuleHeader(module: .monitor, subtitle: "Live CPU, memory, disk and network activity.")
                LazyVGrid(columns: columns, spacing: 16) {
                    cpuCard
                    memoryCard
                    diskCard
                    networkCard
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
    }

    private var stats: SystemStats { vm.stats }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private func gauge(_ value: Double, _ colors: [Color], label: String) -> some View {
        ZStack {
            GaugeRing(value: value, colors: colors, lineWidth: 10)
            VStack(spacing: 0) {
                Text(percent(value))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
        .animation(Theme.spring, value: value)
    }

    private func cardTitle(_ title: String, _ symbol: String, _ color: Color) -> some View {
        Label(title, systemImage: symbol).font(.headline).foregroundStyle(color)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }

    private var cpuCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("CPU", "cpu", Theme.mint)
                HStack(spacing: 18) {
                    gauge(stats.cpuTotal, [Theme.mint, Theme.leaf], label: "Load")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(stats.cpuPerCore.count) cores").font(.caption).foregroundStyle(.secondary)
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(stats.cpuPerCore.enumerated()), id: \.offset) { _, load in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(colors: [Theme.mint, Theme.leaf], startPoint: .bottom, endPoint: .top))
                                    .frame(height: max(3, 54 * load))
                                    .frame(maxHeight: 54, alignment: .bottom)
                            }
                        }
                        .frame(height: 54)
                        .animation(Theme.spring, value: stats.cpuPerCore)
                    }
                }
                Sparkline(values: vm.cpuHistory, color: Theme.mint, maxValue: 1).frame(height: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var memoryCard: some View {
        let m = stats.memory
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardTitle("Memory", "memorychip", Theme.moss)
                    Spacer()
                    Text("Pressure: \(m.pressure.title)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(pressureColor(m.pressure).opacity(0.2), in: Capsule())
                        .foregroundStyle(pressureColor(m.pressure))
                }
                HStack(spacing: 18) {
                    gauge(m.usedFraction, [Theme.leaf, Theme.moss], label: "Used")
                    VStack(spacing: 5) {
                        metric("Used", "\(ByteFormat.string(m.used)) of \(ByteFormat.string(m.total))")
                        metric("App Memory", ByteFormat.string(m.appMemory))
                        metric("Wired", ByteFormat.string(m.wired))
                        metric("Compressed", ByteFormat.string(m.compressed))
                        metric("Cached Files", ByteFormat.string(m.cached))
                    }
                }
                HStack {
                    Button {
                        Task { await vm.freeUpRAM() }
                    } label: {
                        if vm.isPurging {
                            ProgressView().controlSize(.small).frame(width: 100)
                        } else {
                            Label("Free Up RAM", systemImage: "bolt.fill")
                        }
                    }
                    .buttonStyle(PillButtonStyle(colors: [Theme.leaf, Theme.moss]))
                    .disabled(vm.isPurging)
                    if let message = vm.purgeMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pressureColor(_ p: MemoryPressure) -> Color {
        switch p {
        case .normal: return Theme.lime
        case .warning: return Theme.amber
        case .critical: return .red
        }
    }

    private var diskCard: some View {
        let d = stats.disk
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("Disk", "internaldrive", Theme.amber)
                HStack(spacing: 18) {
                    gauge(d.usedFraction, [Theme.amber, Theme.moss], label: "Used")
                    VStack(spacing: 6) {
                        metric("Capacity", ByteFormat.string(d.total))
                        metric("Used", ByteFormat.string(d.used))
                        metric("Available", ByteFormat.string(d.available))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var networkCard: some View {
        let n = stats.network
        let peak = max(vm.downloadHistory.max() ?? 0, vm.uploadHistory.max() ?? 0, 1024)
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("Network", "network", Theme.lime)
                HStack(spacing: 24) {
                    rate("arrow.down.circle.fill", "Download", n.downloadPerSecond, Theme.lime)
                    rate("arrow.up.circle.fill", "Upload", n.uploadPerSecond, Theme.mint)
                }
                ZStack {
                    Sparkline(values: vm.downloadHistory, color: Theme.lime, maxValue: peak)
                    Sparkline(values: vm.uploadHistory, color: Theme.mint, maxValue: peak)
                }
                .frame(height: 60)
                Text("Since launch: ↓ \(ByteFormat.string(Int64(clamping: n.totalReceived)))  ↑ \(ByteFormat.string(Int64(clamping: n.totalSent)))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rate(_ symbol: String, _ title: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(ByteFormat.rate(value))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
        }
    }
}
