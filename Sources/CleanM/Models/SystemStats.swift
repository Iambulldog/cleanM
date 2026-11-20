import Foundation

enum MemoryPressure: Int, Sendable {
    case normal = 1, warning = 2, critical = 4

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

struct MemoryStats: Sendable, Equatable {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var appMemory: UInt64 = 0
    var cached: UInt64 = 0
    var free: UInt64 = 0
    var pressure: MemoryPressure = .normal

    var usedFraction: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }
}

struct DiskStats: Sendable, Equatable {
    var total: Int64 = 0
    var available: Int64 = 0
    var used: Int64 { max(0, total - available) }
    var usedFraction: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }
}

struct NetworkStats: Sendable, Equatable {
    var downloadPerSecond: Double = 0
    var uploadPerSecond: Double = 0
    var totalReceived: UInt64 = 0
    var totalSent: UInt64 = 0
}

struct SystemStats: Sendable, Equatable {
    var cpuTotal: Double = 0          // 0...1
    var cpuPerCore: [Double] = []     // 0...1 each
    var memory = MemoryStats()
    var disk = DiskStats()
    var network = NetworkStats()
    var timestamp = Date()
}
