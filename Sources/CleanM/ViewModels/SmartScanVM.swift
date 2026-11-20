import Foundation
import Observation

@MainActor
@Observable
final class SmartScanVM {
    enum Phase: Equatable { case idle, scanning, results, cleaning, done }

    var phase: Phase = .idle
    var progress: Double = 0
    var statusText = "Ready to scan your Mac"
    var junk: [JunkCategory] = []
    var largeFiles: [LargeFile] = []
    var lastResult: CleanResult?

    private var task: Task<Void, Never>?

    var junkSize: Int64 { junk.filter { $0.kind != .trash }.reduce(0) { $0 + $1.totalSize } }
    var trashSize: Int64 { junk.first { $0.kind == .trash }?.totalSize ?? 0 }
    var cleanableSize: Int64 { junk.reduce(0) { $0 + $1.totalSize } }
    var largeSize: Int64 { largeFiles.reduce(0) { $0 + $1.size } }
    var totalFound: Int64 { cleanableSize + largeSize }

    func start() {
        task?.cancel()
        phase = .scanning
        progress = 0
        lastResult = nil
        junk = []
        largeFiles = []
        statusText = "Looking for junk…"

        task = Task {
            let scanner = DiskScannerService.shared
            let kinds = JunkKind.systemJunk + [.trash]
            let totalUnits = Double(kinds.count + DiskScannerService.largeAndOldRoots.count)
            let counter = ProgressCounter()

            async let junkResult = scanner.scanJunk(kinds) { snapshot in
                Task { @MainActor in
                    guard snapshot.completedUnits > 0 else { return }
                    let done = await counter.bump(junk: snapshot.completedUnits)
                    self.progress = min(0.99, done / totalUnits)
                    self.statusText = "Scanned \(snapshot.label)"
                }
            }
            async let largeResult = scanner.scanLargeAndOld { snapshot in
                Task { @MainActor in
                    if snapshot.totalUnits > 0 {
                        let done = await counter.bump(large: snapshot.completedUnits)
                        self.progress = min(0.99, done / totalUnits)
                    } else {
                        self.statusText = "Searching \(snapshot.label)"
                    }
                }
            }

            let (j, l) = await (junkResult, largeResult)
            guard !Task.isCancelled else { return }
            junk = j
            largeFiles = l
            progress = 1
            statusText = "Scan complete"
            try? await Task.sleep(for: .milliseconds(350))
            phase = .results
        }
    }

    func stop() {
        task?.cancel()
        phase = .idle
        progress = 0
        statusText = "Scan stopped"
    }

    /// Cleans system junk (to Trash) and empties the Trash. Large files are never removed automatically.
    func clean() async {
        phase = .cleaning
        statusText = "Cleaning…"
        let junkRequests = junk.filter { $0.kind != .trash }.flatMap(\.items)
            .map { CleanRequest(url: $0.url, size: $0.size) }
        let trashRequests = (junk.first { $0.kind == .trash }?.items ?? [])
            .map { CleanRequest(url: $0.url, size: $0.size) }

        // Empty the Trash first so the junk we move there afterwards stays recoverable.
        var result = await CleaningService.clean(trashRequests, permanently: true)
        let junkResult = await CleaningService.clean(junkRequests, permanently: false)
        result.merge(junkResult)
        lastResult = result
        statusText = "All clean!"
        phase = .done
    }

    func reset() {
        phase = .idle
        progress = 0
        junk = []
        largeFiles = []
        statusText = "Ready to scan your Mac"
    }
}

/// Combines progress from the two concurrent scans.
private actor ProgressCounter {
    private var junk = 0
    private var large = 0
    func bump(junk value: Int) -> Double { junk = max(junk, value); return Double(junk + large) }
    func bump(large value: Int) -> Double { large = max(large, value); return Double(junk + large) }
}
