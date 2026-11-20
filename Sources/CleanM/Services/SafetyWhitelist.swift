import AppKit

/// Central gatekeeper: every path is checked here immediately before it is removed.
enum SafetyWhitelist {
    enum Verdict: Equatable {
        case allowed
        case denied(String)

        var isAllowed: Bool { self == .allowed }
        var reason: String? {
            if case .denied(let r) = self { return r }
            return nil
        }
    }

    static let ownBundleID = Bundle.main.bundleIdentifier ?? "com.iambulldog.CleanM"

    static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.resolvingSymlinksInPath()
    }

    /// Important Apple caches/data that must never be removed even though they live in the user's Library.
    static let protectedAppleNames: Set<String> = [
        "CloudKit",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.WebKit.Networking",
        "com.apple.WebKit.WebContent",
        "com.apple.bird",
        "com.apple.cloudd",
        "com.apple.CloudDocs",
        "com.apple.iCloudHelper",
        "com.apple.akd",
        "com.apple.ap.adprivacyd",
        "com.apple.HomeKit",
        "com.apple.homed",
        "com.apple.containermanagerd",
        "com.apple.nsurlsessiond",
        "com.apple.findmy.fmipcore",
        "com.apple.icloud.fmfd",
        "com.apple.Messages",
        "com.apple.mail",
        "com.apple.keychain",
        "com.apple.security",
        "com.apple.trustd",
        "com.apple.passd",
        "com.apple.TCC",
        "FamilyCircle",
        "GeoServices",
        "Keychains",
        "Mobile Documents",
    ]

    static let protectedApplePrefixes: [String] = [
        "com.apple.icloud",
        "com.apple.cloud",
        "com.apple.Safari",
        "com.apple.security",
        "com.apple.keychain",
    ]

    /// Folders whose *own* deletion is forbidden (their children may still be eligible).
    static var protectedRoots: Set<String> {
        let h = home
        let lib = h.appendingPathComponent("Library")
        let paths = [
            h, lib,
            lib.appendingPathComponent("Caches"),
            lib.appendingPathComponent("Logs"),
            lib.appendingPathComponent("Application Support"),
            lib.appendingPathComponent("Preferences"),
            lib.appendingPathComponent("Containers"),
            lib.appendingPathComponent("Group Containers"),
            lib.appendingPathComponent("Saved Application State"),
            lib.appendingPathComponent("HTTPStorages"),
            lib.appendingPathComponent("WebKit"),
            lib.appendingPathComponent("Developer"),
            lib.appendingPathComponent("Developer/Xcode"),
            lib.appendingPathComponent("Developer/Xcode/DerivedData"),
            lib.appendingPathComponent("Developer/Xcode/Archives"),
            lib.appendingPathComponent("Caches/Homebrew"),
            lib.appendingPathComponent("Mobile Documents"),
            lib.appendingPathComponent("Keychains"),
            h.appendingPathComponent(".Trash"),
            h.appendingPathComponent("Applications"),
            h.appendingPathComponent("Desktop"),
            h.appendingPathComponent("Documents"),
            h.appendingPathComponent("Downloads"),
            h.appendingPathComponent("Movies"),
            h.appendingPathComponent("Music"),
            h.appendingPathComponent("Pictures"),
            h.appendingPathComponent("Public"),
        ]
        return Set(paths.map { $0.standardizedFileURL.path })
    }

    /// Resolves symlinks in the *parent* chain so that a symlink item itself is removed (not its target),
    /// while any attempt to escape through a symlinked folder is detected.
    static func canonical(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        let parent = standardized.deletingLastPathComponent().resolvingSymlinksInPath()
        return parent.appendingPathComponent(standardized.lastPathComponent)
    }

    static func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    static func runningBundlePaths() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path })
    }

    /// - Parameters:
    ///   - allowApplications: permit top-level `.app` bundles in /Applications or ~/Applications (Uninstaller only).
    ///   - runningIDs: snapshot of running bundle identifiers (pass to avoid re-querying for every file).
    static func verdict(for url: URL,
                        allowApplications: Bool = false,
                        runningIDs: Set<String>? = nil,
                        runningPaths: Set<String>? = nil) -> Verdict {
        let raw = url.standardizedFileURL.path
        if raw.contains("/../") || raw.hasSuffix("/..") { return .denied("Path contains parent references") }

        let target = canonical(url)
        let path = target.path
        let homePath = home.path
        let components = target.pathComponents

        if path == "/" || path.isEmpty { return .denied("Refusing to touch the root volume") }
        if protectedRoots.contains(path) { return .denied("Protected folder") }

        // The app itself.
        if let own = Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path as String?,
           path == own || path.hasPrefix(own + "/") {
            return .denied("CleanM cannot remove itself")
        }
        if components.contains(where: { $0 == ownBundleID || $0.hasPrefix(ownBundleID + ".") }) {
            return .denied("CleanM's own data")
        }

        let isUnderHome = path.hasPrefix(homePath + "/")
        var isApplicationBundle = false
        if !isUnderHome {
            guard allowApplications,
                  target.pathExtension == "app",
                  target.deletingLastPathComponent().path == "/Applications" else {
                return .denied("Outside your home folder")
            }
            isApplicationBundle = true
        } else if allowApplications, target.pathExtension == "app",
                  target.deletingLastPathComponent().path == home.appendingPathComponent("Applications").path {
            isApplicationBundle = true
        }

        if components.contains("System") && path.hasPrefix("/System") { return .denied("System location") }

        // Important Apple caches/data.
        for component in components {
            if protectedAppleNames.contains(component) { return .denied("Protected Apple data (\(component))") }
            if protectedApplePrefixes.contains(where: { component.hasPrefix($0) }) {
                return .denied("Protected Apple data (\(component))")
            }
        }

        // Data belonging to apps that are currently running.
        let ids = runningIDs ?? runningBundleIDs()
        let relevantComponents = isUnderHome
            ? Array(components.dropFirst(home.pathComponents.count))
            : []
        for component in relevantComponents {
            let stem = stripKnownExtensions(component)
            if ids.contains(stem) {
                return .denied("\(stem) is running — quit it first")
            }
        }

        if isApplicationBundle {
            let paths = runningPaths ?? runningBundlePaths()
            if paths.contains(path) { return .denied("App is running — quit it first") }
            if let id = Bundle(url: target)?.bundleIdentifier, id.hasPrefix("com.apple.") {
                return .denied("Apple system app")
            }
        }

        return .allowed
    }

    private static func stripKnownExtensions(_ name: String) -> String {
        for ext in [".savedState", ".plist", ".binarycookies"] where name.hasSuffix(ext) {
            return String(name.dropLast(ext.count))
        }
        return name
    }
}
