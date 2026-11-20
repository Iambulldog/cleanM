import SwiftUI

enum Theme {
    // Natural green palette
    static let mint = Color(red: 0.56, green: 0.89, blue: 0.66)
    static let leaf = Color(red: 0.33, green: 0.74, blue: 0.42)
    static let moss = Color(red: 0.18, green: 0.58, blue: 0.44)
    static let lime = Color(red: 0.74, green: 0.91, blue: 0.38)
    static let amber = Color(red: 0.93, green: 0.72, blue: 0.33)

    static let scanGradient = LinearGradient(colors: [lime, leaf, moss],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let scanAngular = AngularGradient(colors: [lime, leaf, moss, lime], center: .center)

    static let spring = Animation.spring(response: 0.55, dampingFraction: 0.78)
}

enum Module: String, CaseIterable, Identifiable, Hashable {
    case smartScan, junk, largeFiles, uninstaller, monitor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartScan: return "Smart Scan"
        case .junk: return "System Junk"
        case .largeFiles: return "Large & Old Files"
        case .uninstaller: return "Uninstaller"
        case .monitor: return "System Monitor"
        }
    }

    var symbol: String {
        switch self {
        case .smartScan: return "sparkles"
        case .junk: return "trash.circle"
        case .largeFiles: return "doc.on.doc"
        case .uninstaller: return "square.grid.3x3.square"
        case .monitor: return "gauge.with.dots.needle.67percent"
        }
    }

    var colors: [Color] {
        switch self {
        case .smartScan: return [Color(red: 0.04, green: 0.16, blue: 0.10), Color(red: 0.10, green: 0.30, blue: 0.17)]
        case .junk: return [Color(red: 0.03, green: 0.15, blue: 0.13), Color(red: 0.07, green: 0.25, blue: 0.14)]
        case .largeFiles: return [Color(red: 0.13, green: 0.17, blue: 0.06), Color(red: 0.06, green: 0.22, blue: 0.12)]
        case .uninstaller: return [Color(red: 0.05, green: 0.19, blue: 0.10), Color(red: 0.03, green: 0.13, blue: 0.12)]
        case .monitor: return [Color(red: 0.04, green: 0.14, blue: 0.12), Color(red: 0.08, green: 0.24, blue: 0.15)]
        }
    }

    var accent: Color {
        switch self {
        case .smartScan: return Theme.lime
        case .junk: return Theme.mint
        case .largeFiles: return Theme.amber
        case .uninstaller: return Theme.leaf
        case .monitor: return Theme.mint
        }
    }
}
