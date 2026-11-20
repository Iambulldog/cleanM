import Foundation

/// A single file or folder found by a scan that may be removed.
struct ScanItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    var isSelected: Bool

    init(url: URL, size: Int64, isDirectory: Bool, isSelected: Bool = true) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.isDirectory = isDirectory
        self.isSelected = isSelected
    }

    var path: String { url.path }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
