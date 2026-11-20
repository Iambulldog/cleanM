import AppKit
import Observation

@MainActor
@Observable
final class UpdateVM {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed(String)
    }

    var status: Status = .idle

    private let lastCheckKey = "lastUpdateCheck"
    private let autoCheckKey = "checkForUpdatesAutomatically"

    var availableRelease: ReleaseInfo? {
        if case .available(let release) = status { return release }
        return nil
    }

    /// Called at launch: checks at most once a day, and only if the user hasn't turned it off.
    func checkOnLaunchIfNeeded() {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: autoCheckKey) as? Bool ?? true
        guard enabled else { return }
        if let last = defaults.object(forKey: lastCheckKey) as? Date, Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }
        Task { await check(silent: true) }
    }

    func check(silent: Bool = false) async {
        status = .checking
        do {
            let release = try await UpdateService.latestRelease()
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            status = UpdateService.isNewer(release) ? .available(release) : .upToDate
        } catch {
            status = silent ? .idle : .failed(error.localizedDescription)
        }
    }

    func openDownload() {
        guard let release = availableRelease else {
            NSWorkspace.shared.open(AppInfo.releasesURL)
            return
        }
        NSWorkspace.shared.open(release.downloadURL ?? release.pageURL)
    }

    func openReleasePage() {
        NSWorkspace.shared.open(availableRelease?.pageURL ?? AppInfo.releasesURL)
    }
}
