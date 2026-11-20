import AppKit

enum AppInfo {
    static let repository = "Iambulldog/cleanM"
    static var repositoryURL: URL { URL(string: "https://github.com/\(repository)")! }
    static var releasesURL: URL { URL(string: "https://github.com/\(repository)/releases")! }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static var versionDescription: String { "Version \(version) (\(build))" }
}

/// Semantic version (major.minor.patch) parsed from strings like "v1.2.3" or "1.2".
struct SemanticVersion: Comparable, CustomStringConvertible {
    let parts: [Int]

    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let core = text.split(separator: "-").first.map(String.init) ?? text
        let numbers = core.split(separator: ".").map { Int($0) }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil }) else { return nil }
        var values = numbers.compactMap { $0 }
        while values.count < 3 { values.append(0) }
        parts = values
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        for (a, b) in zip(lhs.parts, rhs.parts) where a != b { return a < b }
        return lhs.parts.count < rhs.parts.count
    }

    var description: String { parts.map(String.init).joined(separator: ".") }
}

struct ReleaseInfo: Sendable, Equatable {
    let version: String
    let name: String
    let notes: String
    let pageURL: URL
    let downloadURL: URL?
}

enum UpdateError: LocalizedError {
    case noReleases
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .noReleases: return "No releases have been published yet."
        case .badResponse(let code): return "GitHub returned an error (\(code))."
        }
    }
}

enum UpdateService {
    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let name: String?
        let body: String?
        let html_url: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    /// Fetches the latest published (non-draft, non-prerelease) release from GitHub.
    static func latestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(AppInfo.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CleanM/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { throw UpdateError.noReleases }
        guard (200..<300).contains(status) else { throw UpdateError.badResponse(status) }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let zip = release.assets.first { $0.name.hasSuffix(".zip") || $0.name.hasSuffix(".dmg") }
        return ReleaseInfo(version: release.tag_name,
                           name: release.name ?? release.tag_name,
                           notes: release.body ?? "",
                           pageURL: release.html_url,
                           downloadURL: zip?.browser_download_url)
    }

    static func isNewer(_ release: ReleaseInfo, than current: String = AppInfo.version) -> Bool {
        guard let remote = SemanticVersion(release.version), let local = SemanticVersion(current) else { return false }
        return remote > local
    }
}
