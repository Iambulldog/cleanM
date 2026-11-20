import SwiftUI

struct SmartScanView: View {
    @Environment(SmartScanVM.self) private var vm
    var onReviewLargeFiles: () -> Void

    @State private var confirmClean = false
    @State private var showCheck = false

    var body: some View {
        ZStack {
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                switch vm.phase {
                case .idle: idle
                case .scanning: scanning
                case .results: results
                case .cleaning: cleaning
                case .done: done
                }
                Spacer(minLength: 0)
            }
            .padding(30)
            .animation(Theme.spring, value: vm.phase)

            if vm.phase == .done { ConfettiView() }
        }
        .confirmationDialog("Clean \(ByteFormat.string(vm.cleanableSize))?", isPresented: $confirmClean) {
            Button("Clean") { Task { await vm.clean() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(cleanMessage)
        }
    }

    private var cleanMessage: String {
        var lines = ["System junk will be moved to the Trash."]
        if vm.trashSize > 0 {
            lines.append("Items already in the Trash (\(ByteFormat.string(vm.trashSize))) will be deleted permanently.")
        }
        lines.append("Large & old files are never removed automatically.")
        return lines.joined(separator: " ")
    }

    // MARK: Phases

    private var idle: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                Text("Welcome to CleanM")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("One scan finds system junk, Trash, and large forgotten files.")
                    .foregroundStyle(.secondary)
            }
            ScanButton(title: "Scan", subtitle: "Smart Scan") { vm.start() }
            HStack(spacing: 22) {
                feature("trash.circle", "System Junk", Theme.mint)
                feature("trash", "Trash", Theme.leaf)
                feature("doc.on.doc", "Large & Old", Theme.amber)
            }
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func feature(_ symbol: String, _ title: String, _ color: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.callout.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(.white.opacity(0.08), in: Capsule())
    }

    private var scanning: some View {
        VStack(spacing: 26) {
            ZStack {
                ProgressRing(progress: vm.progress, lineWidth: 16)
                    .frame(width: 230, height: 230)
                VStack(spacing: 4) {
                    Text("\(Int(vm.progress * 100))%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("Scanning")
                        .foregroundStyle(.secondary)
                }
            }
            Text(vm.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 420)
            Button("Stop") { vm.stop() }
                .buttonStyle(PillButtonStyle(prominent: false))
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private var results: some View {
        VStack(spacing: 26) {
            VStack(spacing: 6) {
                Text(ByteFormat.string(vm.totalFound))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.scanGradient)
                Text("found on your Mac")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                summaryCard(symbol: "trash.circle", color: Theme.mint, title: "System Junk",
                            value: ByteFormat.string(vm.junkSize), note: "Will be moved to Trash")
                summaryCard(symbol: "trash", color: Theme.leaf, title: "Trash",
                            value: ByteFormat.string(vm.trashSize), note: "Will be emptied")
                Button(action: onReviewLargeFiles) {
                    summaryCard(symbol: "doc.on.doc", color: Theme.amber, title: "Large & Old Files",
                                value: ByteFormat.string(vm.largeSize),
                                note: "\(vm.largeFiles.count) files · Review →")
                }
                .buttonStyle(.plain)
                .help("Large files are not removed automatically. Open the module to review them.")
            }
            .frame(maxWidth: 760)

            HStack(spacing: 22) {
                ScanButton(title: "Clean", subtitle: ByteFormat.string(vm.cleanableSize), size: 150) {
                    if vm.cleanableSize > 0 { confirmClean = true }
                }
                .disabled(vm.cleanableSize == 0)
                .opacity(vm.cleanableSize == 0 ? 0.5 : 1)
            }
            Button("Scan Again") { vm.start() }
                .buttonStyle(PillButtonStyle(prominent: false))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func summaryCard(symbol: String, color: Color, title: String, value: String, note: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title).font(.headline)
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cleaning: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.4)
                .frame(width: 120, height: 120)
            Text("Cleaning…").font(.title3.weight(.semibold))
        }
        .transition(.opacity)
    }

    private var done: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Theme.scanGradient)
                    .frame(width: 170, height: 170)
                    .shadow(color: Theme.leaf.opacity(0.6), radius: 30)
                Image(systemName: "checkmark")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(showCheck ? 1 : 0.2)
                    .opacity(showCheck ? 1 : 0)
            }
            .onAppear {
                showCheck = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.15)) { showCheck = true }
            }
            Text("Your Mac is clean!")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            if let result = vm.lastResult {
                Text("Cleaned \(ByteFormat.string(result.freedBytes))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if !result.failures.isEmpty {
                    ResultBanner(result: result).frame(maxWidth: 520)
                }
            }
            if !vm.largeFiles.isEmpty {
                Button("Review \(vm.largeFiles.count) Large & Old Files", action: onReviewLargeFiles)
                    .buttonStyle(PillButtonStyle(colors: [Theme.amber, Theme.moss]))
            }
            Button("Done") { vm.reset() }
                .buttonStyle(PillButtonStyle(prominent: false))
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
