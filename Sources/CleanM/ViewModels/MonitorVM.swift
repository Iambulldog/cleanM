import Foundation
import Observation

@MainActor
@Observable
final class MonitorVM {
    var stats = SystemStats()
    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []
    var downloadHistory: [Double] = []
    var uploadHistory: [Double] = []

    var isPurging = false
    var purgeMessage: String?

    let interval: Duration = .milliseconds(1500)
    private let historyLength = 60
    private let service = SystemMonitorService()
    private var loop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        _ = service.sample() // prime deltas
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(for: self.interval)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    private func tick() {
        let s = service.sample()
        stats = s
        append(&cpuHistory, s.cpuTotal)
        append(&memoryHistory, s.memory.usedFraction)
        append(&downloadHistory, s.network.downloadPerSecond)
        append(&uploadHistory, s.network.uploadPerSecond)
    }

    private func append(_ array: inout [Double], _ value: Double) {
        array.append(value)
        if array.count > historyLength { array.removeFirst(array.count - historyLength) }
    }

    func freeUpRAM() async {
        guard !isPurging else { return }
        isPurging = true
        purgeMessage = "Waiting for authorization…"
        let before = SystemMonitorService.sampleMemory()
        do {
            try await MemoryPurgeService.purge()
            try? await Task.sleep(for: .milliseconds(800))
            let after = SystemMonitorService.sampleMemory()
            let reclaimed = Int64(after.free) - Int64(before.free)
            purgeMessage = reclaimed > 0
                ? "Freed \(ByteFormat.string(reclaimed)) of memory"
                : "Memory purged — macOS was already using RAM efficiently"
            tick()
        } catch {
            purgeMessage = error.localizedDescription
        }
        isPurging = false
    }
}
