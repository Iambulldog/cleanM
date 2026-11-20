import Foundation

enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        f.includesUnit = true
        f.isAdaptive = true
        return f
    }()

    static func string(_ bytes: Int64) -> String {
        if bytes <= 0 { return "Zero KB" }
        return formatter.string(fromByteCount: bytes)
    }

    private static let memoryFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        f.allowedUnits = [.useMB, .useGB]
        return f
    }()

    /// RAM sizes use binary units, matching Activity Monitor (e.g. 18 GB, not 19.33 GB).
    static func string(_ bytes: UInt64) -> String {
        memoryFormatter.string(fromByteCount: Int64(clamping: bytes))
    }

    /// Bytes per second, e.g. "1.2 MB/s".
    static func rate(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        if value < 1024 { return String(format: "%.0f B/s", value) }
        return formatter.string(fromByteCount: Int64(value)) + "/s"
    }
}

extension Date {
    var relativeDescription: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: Date())
    }
}
