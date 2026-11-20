import AppKit
import SwiftUI

struct JunkView: View {
    @Environment(JunkVM.self) private var vm
    @AppStorage("deletePermanently") private var deletePermanently = false
    @State private var confirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModuleHeader(module: .junk, subtitle: "Caches, logs, and developer leftovers that are safe to remove.")

            switch vm.phase {
            case .idle:
                Spacer()
                HStack { Spacer(); ScanButton(title: "Scan", subtitle: "System Junk") { vm.scan() }; Spacer() }
                Spacer()
            case .scanning:
                Spacer()
                VStack(spacing: 18) {
                    ProgressRing(progress: vm.progress.fraction, lineWidth: 12)
                        .frame(width: 150, height: 150)
                        .overlay(Text(ByteFormat.string(vm.progress.bytesFound))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit())
                    Text(vm.progress.label.isEmpty ? "Scanning…" : "Finished \(vm.progress.label)")
                        .foregroundStyle(.secondary)
                    Button("Stop") { vm.cancel() }.buttonStyle(PillButtonStyle(prominent: false))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            case .scanned, .cleaning, .done:
                list
                footer
            }
        }
        .padding(24)
        .animation(Theme.spring, value: vm.phase)
        .confirmationDialog(deletePermanently ? "Permanently delete \(vm.selectedCount) items?" : "Move \(vm.selectedCount) items to the Trash?",
                            isPresented: $confirm) {
            Button(deletePermanently ? "Delete Permanently" : "Move to Trash",
                   role: deletePermanently ? .destructive : nil) {
                Task { await vm.clean(permanently: deletePermanently) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deletePermanently
                 ? "\(ByteFormat.string(vm.selectedSize)) will be removed. This can't be undone."
                 : "\(ByteFormat.string(vm.selectedSize)) will be moved to the Trash. You can restore it from there.")
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let result = vm.lastResult { ResultBanner(result: result) }
                ForEach(vm.categories) { category in
                    CategoryCard(category: category)
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected").font(.caption).foregroundStyle(.secondary)
                Text(ByteFormat.string(vm.selectedSize))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            Toggle("Delete permanently", isOn: $deletePermanently)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Off: items go to the Trash (recommended).")
            Button("Rescan") { vm.scan() }
                .buttonStyle(PillButtonStyle(prominent: false))
            Button {
                confirm = true
            } label: {
                if vm.phase == .cleaning {
                    ProgressView().controlSize(.small).frame(width: 60)
                } else {
                    Text("Clean")
                }
            }
            .buttonStyle(PillButtonStyle(colors: [Theme.leaf, Theme.moss]))
            .disabled(vm.selectedCount == 0 || vm.phase == .cleaning)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CategoryCard: View {
    @Environment(JunkVM.self) private var vm
    let category: JunkCategory

    var body: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    CheckBox(state: category.selectionState) { vm.toggleCategory(category.kind) }
                        .disabled(category.items.isEmpty)
                    Image(systemName: category.kind.symbol)
                        .font(.title3)
                        .foregroundStyle(Theme.mint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.kind.title).font(.headline)
                        Text("\(category.items.count) items · \(category.kind.subtitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SizeBadge(bytes: category.selectedSize, tint: Theme.mint)
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(category.isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .opacity(category.items.isEmpty ? 0.3 : 1)
                }
                .padding(14)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !category.items.isEmpty else { return }
                    withAnimation(Theme.spring) { vm.toggleExpanded(category.kind) }
                }

                if category.isExpanded {
                    Divider().opacity(0.4)
                    LazyVStack(spacing: 0) {
                        ForEach(category.items) { item in
                            ItemRow(item: item) { vm.toggleItem(item.id, in: category.kind) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct ItemRow: View {
    let item: ScanItem
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CheckBox(state: item.isSelected, action: toggle)
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.callout).lineLimit(1)
                Text(item.displayPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormat.string(item.size)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reveal in Finder")
            .accessibilityLabel("Reveal \(item.name) in Finder")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }
}
