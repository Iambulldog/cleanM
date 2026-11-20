import Foundation

enum JunkKind: String, CaseIterable, Identifiable, Sendable {
    case userCaches
    case logs
    case xcodeDerivedData
    case xcodeArchives
    case homebrewCache
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userCaches: return "User Cache Files"
        case .logs: return "User Log Files"
        case .xcodeDerivedData: return "Xcode Derived Data"
        case .xcodeArchives: return "Xcode Archives"
        case .homebrewCache: return "Homebrew Cache"
        case .trash: return "Trash"
        }
    }

    var subtitle: String {
        switch self {
        case .userCaches: return "Temporary data apps can rebuild on demand"
        case .logs: return "Diagnostic logs written by apps"
        case .xcodeDerivedData: return "Intermediate build products and indexes"
        case .xcodeArchives: return "Old app archives created by Xcode"
        case .homebrewCache: return "Downloaded bottles and source tarballs"
        case .trash: return "Items already moved to the Trash"
        }
    }

    var symbol: String {
        switch self {
        case .userCaches: return "internaldrive"
        case .logs: return "doc.text.magnifyingglass"
        case .xcodeDerivedData: return "hammer"
        case .xcodeArchives: return "archivebox"
        case .homebrewCache: return "mug"
        case .trash: return "trash"
        }
    }

    /// Root folders whose first-level children are reported as items.
    var roots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library", isDirectory: true)
        switch self {
        case .userCaches: return [lib.appendingPathComponent("Caches", isDirectory: true)]
        case .logs: return [lib.appendingPathComponent("Logs", isDirectory: true)]
        case .xcodeDerivedData: return [lib.appendingPathComponent("Developer/Xcode/DerivedData", isDirectory: true)]
        case .xcodeArchives: return [lib.appendingPathComponent("Developer/Xcode/Archives", isDirectory: true)]
        case .homebrewCache: return [lib.appendingPathComponent("Caches/Homebrew", isDirectory: true)]
        case .trash: return [home.appendingPathComponent(".Trash", isDirectory: true)]
        }
    }

    /// Child names that are skipped for this category.
    var excludedChildNames: Set<String> {
        switch self {
        case .userCaches: return ["Homebrew"]
        default: return []
        }
    }

    /// Categories shown in the System Junk module.
    static var systemJunk: [JunkKind] { [.userCaches, .logs, .xcodeDerivedData, .xcodeArchives, .homebrewCache] }
}

struct JunkCategory: Identifiable, Hashable, Sendable {
    let kind: JunkKind
    var items: [ScanItem]
    var isExpanded: Bool = false

    var id: JunkKind { kind }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedItems: [ScanItem] { items.filter(\.isSelected) }

    var selectionState: Bool? {
        let selected = items.filter(\.isSelected).count
        if selected == 0 { return false }
        if selected == items.count { return true }
        return nil
    }
}
