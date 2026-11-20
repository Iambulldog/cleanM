import AppKit

enum PermissionService {
    /// Full Disk Access cannot be queried directly; we probe files that are only readable with it.
    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Safari/Bookmarks.plist"),
            home.appendingPathComponent("Library/Safari/CloudTabs.db"),
        ]
        for url in probes {
            if let handle = try? FileHandle(forReadingFrom: url) {
                try? handle.close()
                return true
            }
        }
        return false
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
