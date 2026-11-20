import AppKit

enum AppInventoryService {
    static var applicationFolders: [URL] {
        [URL(fileURLWithPath: "/Applications", isDirectory: true),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]
    }

    /// Lists `.app` bundles in /Applications and ~/Applications (top level only).
    static func installedApps() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var urls: [URL] = []
            for folder in applicationFolders {
                let children = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                            options: [.skipsHiddenFiles])) ?? []
                urls += children.filter { $0.pathExtension == "app" }
            }

            return await withTaskGroup(of: InstalledApp?.self, returning: [InstalledApp].self) { group in
                for url in urls {
                    group.addTask { makeApp(url) }
                }
                var apps: [InstalledApp] = []
                for await app in group { if let app { apps.append(app) } }
                return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }.value
    }

    private static func makeApp(_ url: URL) -> InstalledApp? {
        let bundle = Bundle(url: url)
        let info = bundle?.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier
        let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        let resolved = url.resolvingSymlinksInPath().path
        let isSystem = resolved.hasPrefix("/System") || (bundleID?.hasPrefix("com.apple.") ?? false)
        let size = DiskScannerService.allocatedSize(of: url)
        return InstalledApp(id: url, url: url, name: name, bundleID: bundleID, version: version,
                            icon: icon, size: size, isSystemApp: isSystem)
    }

    static func isRunning(_ app: InstalledApp) -> Bool {
        let path = app.url.standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.contains { running in
            if let id = app.bundleID, running.bundleIdentifier == id { return true }
            return running.bundleURL?.standardizedFileURL.path == path
        }
    }

    // MARK: Leftovers

    private struct SearchLocation {
        let relativePath: String
        let group: String
        let matchesName: Bool
    }

    private static let locations: [SearchLocation] = [
        .init(relativePath: "Library/Application Support", group: "Application Support", matchesName: true),
        .init(relativePath: "Library/Preferences", group: "Preferences", matchesName: false),
        .init(relativePath: "Library/Caches", group: "Caches", matchesName: true),
        .init(relativePath: "Library/Saved Application State", group: "Saved State", matchesName: false),
        .init(relativePath: "Library/Containers", group: "Containers", matchesName: false),
        .init(relativePath: "Library/Group Containers", group: "Group Containers", matchesName: false),
        .init(relativePath: "Library/HTTPStorages", group: "HTTP Storage", matchesName: false),
        .init(relativePath: "Library/WebKit", group: "WebKit", matchesName: false),
        .init(relativePath: "Library/Logs", group: "Logs", matchesName: true),
        .init(relativePath: "Library/Cookies", group: "Cookies", matchesName: false),
    ]

    /// Finds support files left behind by `app`, matched by bundle identifier (and app name where it is safe).
    static func leftovers(for app: InstalledApp) async -> [Leftover] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            let id = app.bundleID?.lowercased()
            let name = app.name.lowercased()
            let fileName = app.url.deletingPathExtension().lastPathComponent.lowercased()
            var found: [Leftover] = []
            var seen = Set<String>()

            for location in locations {
                let folder = home.appendingPathComponent(location.relativePath, isDirectory: true)
                guard let children = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
                for child in children {
                    let entry = child.lastPathComponent.lowercased()
                    var matched = false
                    if let id, !id.isEmpty {
                        matched = entry == id
                            || entry.hasPrefix(id + ".")          // .plist, .savedState, .binarycookies
                            || entry.hasSuffix("." + id)          // TEAMID.com.vendor.app group containers
                    }
                    if !matched, location.matchesName, name.count >= 3 {
                        matched = entry == name || entry == fileName
                    }
                    guard matched, !seen.contains(child.path) else { continue }
                    guard SafetyWhitelist.verdict(for: child).isAllowed else { continue }
                    seen.insert(child.path)
                    found.append(Leftover(url: child, size: DiskScannerService.allocatedSize(of: child),
                                          group: location.group))
                }
            }
            return found.sorted { $0.size > $1.size }
        }.value
    }

    /// Moves the app and the selected leftovers to the Trash.
    static func uninstall(_ app: InstalledApp, leftovers: [Leftover]) async -> CleanResult {
        if app.isSystemApp {
            return CleanResult(failures: [CleanFailure(url: app.url, message: "System apps can't be uninstalled.")])
        }
        if isRunning(app) {
            return CleanResult(failures: [CleanFailure(url: app.url, message: "\(app.name) is running. Quit it first.")])
        }
        var result = await CleaningService.clean([CleanRequest(url: app.url, size: app.size)],
                                                 permanently: false, allowApplications: true)
        guard result.failures.isEmpty else { return result }
        let extra = await CleaningService.clean(leftovers.map { CleanRequest(url: $0.url, size: $0.size) },
                                                permanently: false)
        result.merge(extra)
        return result
    }
}
