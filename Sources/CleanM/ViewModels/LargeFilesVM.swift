import Foundation
import Observation

@MainActor
@Observable
final class LargeFilesVM {
    var phase: ModulePhase = .idle
    var files: [LargeFile] = []
    var statusText = ""
    var kindFilter: FileKind = .all
    var sizeFilter: SizeFilter = .any
    var ageFilter: AgeFilter = .any
    var searchText = ""
    var lastResult: CleanResult?
    var focusedID: LargeFile.ID?

    private var task: Task<Void, Never>?

    var filtered: [LargeFile] {
        files.filter { file in
            (kindFilter == .all || file.kind == kindFilter)
                && file.size >= sizeFilter.minimum
                && (ageFilter.cutoff.map { cutoff in (file.lastAccess ?? .distantFuture) < cutoff } ?? true)
                && (searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var selected: [LargeFile] { files.filter(\.isSelected) }
    var selectedSize: Int64 { selected.reduce(0) { $0 + $1.size } }

    func scan() {
        task?.cancel()
        phase = .scanning
        files = []
        lastResult = nil
        statusText = "Starting…"
        task = Task {
            let result = await DiskScannerService.shared.scanLargeAndOld { snapshot in
                Task { @MainActor in self.statusText = snapshot.label }
            }
            guard !Task.isCancelled else { return }
            files = result
            phase = .scanned
        }
    }

    /// Reuses results from Smart Scan so the user doesn't have to scan twice.
    func adopt(_ scanned: [LargeFile]) {
        guard phase == .idle || phase == .scanned, !scanned.isEmpty else { return }
        files = scanned.map { LargeFile(url: $0.url, size: $0.size, lastAccess: $0.lastAccess, kind: $0.kind) }
        lastResult = nil
        phase = .scanned
    }

    func cancel() {
        task?.cancel()
        phase = files.isEmpty ? .idle : .scanned
    }

    func toggle(_ id: LargeFile.ID) {
        guard let i = files.firstIndex(where: { $0.id == id }) else { return }
        files[i].isSelected.toggle()
    }

    func setAllVisible(_ value: Bool) {
        let visible = Set(filtered.map(\.id))
        for i in files.indices where visible.contains(files[i].id) { files[i].isSelected = value }
    }

    func removeSelected(permanently: Bool) async {
        let targets = selected
        guard !targets.isEmpty else { return }
        phase = .cleaning
        let result = await CleaningService.clean(targets.map { CleanRequest(url: $0.url, size: $0.size) },
                                                 permanently: permanently)
        lastResult = result
        let failed = Set(result.failures.map(\.url))
        files.removeAll { $0.isSelected && !failed.contains($0.url) }
        phase = .scanned
    }
}
