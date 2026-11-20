import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    let icon: NSImage
    let size: Int64
    let isSystemApp: Bool

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Leftover: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let size: Int64
    let group: String
    var isSelected: Bool

    init(url: URL, size: Int64, group: String, isSelected: Bool = true) {
        self.id = UUID()
        self.url = url
        self.size = size
        self.group = group
        self.isSelected = isSelected
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}
