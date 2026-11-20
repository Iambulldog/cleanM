import Foundation
import Observation

enum ModulePhase: Equatable {
    case idle, scanning, scanned, cleaning, done
}

@MainActor
@Observable
final class JunkVM {
    var phase: ModulePhase = .idle
    var categories: [JunkCategory] = []
    var progress = ScanProgress(label: "", completedUnits: 0, totalUnits: 0, bytesFound: 0)
    var lastResult: CleanResult?

    private var scanTask: Task<Void, Never>?

    var totalSize: Int64 { categories.reduce(0) { $0 + $1.totalSize } }
    var selectedSize: Int64 { categories.reduce(0) { $0 + $1.selectedSize } }
    var selectedCount: Int { categories.reduce(0) { $0 + $1.selectedItems.count } }

    func scan() {
        scanTask?.cancel()
        phase = .scanning
        lastResult = nil
        categories = []
        scanTask = Task {
            let result = await DiskScannerService.shared.scanJunk(JunkKind.systemJunk) { snapshot in
                Task { @MainActor in self.progress = snapshot }
            }
            guard !Task.isCancelled else { return }
            categories = result
            phase = .scanned
        }
    }

    func cancel() {
        scanTask?.cancel()
        phase = categories.isEmpty ? .idle : .scanned
    }

    func toggleCategory(_ kind: JunkKind) {
        guard let index = categories.firstIndex(where: { $0.kind == kind }) else { return }
        let newValue = categories[index].selectionState != true
        for i in categories[index].items.indices { categories[index].items[i].isSelected = newValue }
    }

    func toggleItem(_ itemID: UUID, in kind: JunkKind) {
        guard let c = categories.firstIndex(where: { $0.kind == kind }),
              let i = categories[c].items.firstIndex(where: { $0.id == itemID }) else { return }
        categories[c].items[i].isSelected.toggle()
    }

    func toggleExpanded(_ kind: JunkKind) {
        guard let c = categories.firstIndex(where: { $0.kind == kind }) else { return }
        categories[c].isExpanded.toggle()
    }

    func clean(permanently: Bool) async {
        let requests = categories.flatMap(\.selectedItems).map { CleanRequest(url: $0.url, size: $0.size) }
        guard !requests.isEmpty else { return }
        phase = .cleaning
        let result = await CleaningService.clean(requests, permanently: permanently)
        lastResult = result
        let failed = Set(result.failures.map { $0.url.path })
        // Remove items that were actually cleaned, keep failed ones visible.
        for c in categories.indices {
            categories[c].items.removeAll { $0.isSelected && !failed.contains($0.path) }
        }
        phase = .done
    }
}
