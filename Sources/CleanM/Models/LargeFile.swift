import Foundation
import UniformTypeIdentifiers

enum FileKind: String, CaseIterable, Identifiable, Sendable {
    case all, movie, archive, diskImage, document, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Kinds"
        case .movie: return "Movies"
        case .archive: return "Archives"
        case .diskImage: return "Disk Images"
        case .document: return "Documents"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .movie: return "film"
        case .archive: return "doc.zipper"
        case .diskImage: return "opticaldiscdrive"
        case .document: return "doc.richtext"
        case .other: return "doc"
        }
    }

    static func classify(_ type: UTType?) -> FileKind {
        guard let type else { return .other }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .movie }
        if type.conforms(to: .diskImage) { return .diskImage }
        if type.conforms(to: .archive) { return .archive }
        if type.conforms(to: .pdf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet)
            || type.conforms(to: .text) || type.conforms(to: .compositeContent) { return .document }
        return .other
    }
}

enum AgeFilter: String, CaseIterable, Identifiable, Sendable {
    case any, olderThan6Months, olderThan1Year

    var id: String { rawValue }
    var title: String {
        switch self {
        case .any: return "Any Age"
        case .olderThan6Months: return "Not Opened > 6 Months"
        case .olderThan1Year: return "Not Opened > 1 Year"
        }
    }

    var cutoff: Date? {
        switch self {
        case .any: return nil
        case .olderThan6Months: return Calendar.current.date(byAdding: .month, value: -6, to: Date())
        case .olderThan1Year: return Calendar.current.date(byAdding: .year, value: -1, to: Date())
        }
    }
}

enum SizeFilter: String, CaseIterable, Identifiable, Sendable {
    case any, over100MB, over500MB, over1GB

    var id: String { rawValue }
    var title: String {
        switch self {
        case .any: return "Any Size"
        case .over100MB: return "> 100 MB"
        case .over500MB: return "> 500 MB"
        case .over1GB: return "> 1 GB"
        }
    }

    var minimum: Int64 {
        switch self {
        case .any: return 0
        case .over100MB: return 100 * 1_000_000
        case .over500MB: return 500 * 1_000_000
        case .over1GB: return 1_000_000_000
        }
    }
}

struct LargeFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let size: Int64
    let lastAccess: Date?
    let kind: FileKind
    var isSelected: Bool

    init(url: URL, size: Int64, lastAccess: Date?, kind: FileKind, isSelected: Bool = false) {
        self.id = UUID()
        self.url = url
        self.size = size
        self.lastAccess = lastAccess
        self.kind = kind
        self.isSelected = isSelected
    }

    var name: String { url.lastPathComponent }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let parent = url.deletingLastPathComponent().path
        return parent.hasPrefix(home) ? "~" + parent.dropFirst(home.count) : parent
    }

    static let largeThreshold: Int64 = 100 * 1_000_000
    static var oldCutoff: Date { Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date() }

    var isLarge: Bool { size >= Self.largeThreshold }
    var isOld: Bool {
        guard let lastAccess else { return false }
        return lastAccess < Self.oldCutoff
    }
}
