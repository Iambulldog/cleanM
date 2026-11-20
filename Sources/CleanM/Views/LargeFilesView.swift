import AppKit
import SwiftUI

struct LargeFilesView: View {
    @Environment(LargeFilesVM.self) private var vm
    @State private var quickLook = QuickLookController()
    @State private var confirmRemove = false
    @FocusState private var listFocused: Bool

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(module: .largeFiles,
                         subtitle: "Files over 100 MB or not opened for 6 months in Downloads, Documents, Desktop and Movies.")

            switch vm.phase {
            case .idle:
                Spacer()
                HStack { Spacer(); ScanButton(title: "Scan", subtitle: "Large & Old") { vm.scan() }; Spacer() }
                Spacer()
            case .scanning:
                Spacer()
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text(vm.statusText).foregroundStyle(.secondary).lineLimit(1)
                    Button("Stop") { vm.cancel() }.buttonStyle(PillButtonStyle(prominent: false))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            case .scanned, .cleaning, .done:
                filters(vm: $vm)
                if let result = vm.lastResult { ResultBanner(result: result) }
                fileList
                footer
            }
        }
        .padding(24)
        .background(QuickLookPreview(controller: quickLook).frame(width: 0, height: 0))
        .animation(Theme.spring, value: vm.phase)
        .confirmationDialog("Remove \(vm.selected.count) files (\(ByteFormat.string(vm.selectedSize)))?",
                            isPresented: $confirmRemove) {
            Button("Move to Trash") { Task { await vm.removeSelected(permanently: false) } }
            Button("Delete Permanently", role: .destructive) { Task { await vm.removeSelected(permanently: true) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Moving to the Trash lets you restore files later. Permanent deletion can't be undone.")
        }
    }

    private func filters(vm: Bindable<LargeFilesVM>) -> some View {
        HStack(spacing: 10) {
            Picker("Kind", selection: vm.kindFilter) {
                ForEach(FileKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            .frame(width: 170)
            Picker("Size", selection: vm.sizeFilter) {
                ForEach(SizeFilter.allCases) { Text($0.title).tag($0) }
            }
            .frame(width: 140)
            Picker("Age", selection: vm.ageFilter) {
                ForEach(AgeFilter.allCases) { Text($0.title).tag($0) }
            }
            .frame(width: 210)
            Spacer()
            TextField("Search", text: vm.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
        }
        .labelsHidden()
    }

    private var fileList: some View {
        let files = vm.filtered
        return GlassCard(padding: 0) {
            if files.isEmpty {
                EmptyStateView(symbol: "checkmark.seal", title: "Nothing here",
                               message: "No files match the current filters.")
                    .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack {
                            CheckBox(state: allVisibleState(files), tint: Theme.amber) {
                                vm.setAllVisible(allVisibleState(files) != true)
                            }
                            Text("\(files.count) files · \(ByteFormat.string(files.reduce(0) { $0 + $1.size }))")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("Press Space to Quick Look").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        ForEach(files) { file in
                            LargeFileRow(file: file,
                                         isFocused: vm.focusedID == file.id,
                                         toggle: { vm.toggle(file.id) },
                                         preview: { quickLook.toggle(urls: [file.url]) })
                                .onTapGesture {
                                    vm.focusedID = file.id
                                    listFocused = true
                                }
                        }
                    }
                }
                .focusable()
                .focused($listFocused)
                .focusEffectDisabled()
                .onKeyPress(.space) {
                    previewFocused()
                    return .handled
                }
                .onKeyPress(.downArrow) { moveFocus(1, in: files); return .handled }
                .onKeyPress(.upArrow) { moveFocus(-1, in: files); return .handled }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func allVisibleState(_ files: [LargeFile]) -> Bool? {
        let selected = files.filter(\.isSelected).count
        if selected == 0 { return false }
        return selected == files.count ? true : nil
    }

    private func moveFocus(_ delta: Int, in files: [LargeFile]) {
        guard !files.isEmpty else { return }
        let index = files.firstIndex { $0.id == vm.focusedID } ?? (delta > 0 ? -1 : files.count)
        let next = min(max(index + delta, 0), files.count - 1)
        vm.focusedID = files[next].id
    }

    private func previewFocused() {
        let urls: [URL]
        if let focused = vm.files.first(where: { $0.id == vm.focusedID }) {
            urls = [focused.url]
        } else {
            urls = vm.selected.map(\.url)
        }
        quickLook.toggle(urls: urls)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.selected.count) selected").font(.caption).foregroundStyle(.secondary)
                Text(ByteFormat.string(vm.selectedSize))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
            Spacer()
            Button("Rescan") { vm.scan() }.buttonStyle(PillButtonStyle(prominent: false))
            Button {
                confirmRemove = true
            } label: {
                if vm.phase == .cleaning { ProgressView().controlSize(.small).frame(width: 70) } else { Text("Remove…") }
            }
            .buttonStyle(PillButtonStyle(colors: [Theme.amber, Theme.moss]))
            .disabled(vm.selected.isEmpty || vm.phase == .cleaning)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LargeFileRow: View {
    let file: LargeFile
    let isFocused: Bool
    let toggle: () -> Void
    let preview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CheckBox(state: file.isSelected, tint: Theme.amber, action: toggle)
            FileIcon(url: file.url, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(file.name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    if file.isLarge { tag("Large", Theme.amber) }
                    if file.isOld { tag("Old", Theme.leaf) }
                }
                Text(file.displayPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
            }
            Spacer()
            Text(file.lastAccess.map { "Opened \($0.relativeDescription)" } ?? "Never opened")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
            SizeBadge(bytes: file.size, tint: Theme.amber)
                .frame(width: 90, alignment: .trailing)
            Button(action: preview) { Image(systemName: "eye") }
                .buttonStyle(.plain)
                .help("Quick Look")
                .accessibilityLabel("Quick Look \(file.name)")
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                .accessibilityLabel("Reveal \(file.name) in Finder")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isFocused ? Color.white.opacity(0.10) : .clear)
        .contentShape(Rectangle())
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(color.opacity(0.25), in: Capsule())
            .foregroundStyle(color)
    }
}
