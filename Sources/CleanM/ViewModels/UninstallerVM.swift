import Foundation
import Observation

@MainActor
@Observable
final class UninstallerVM {
    var apps: [InstalledApp] = []
    var isLoading = false
    var searchText = ""
    var selectedAppID: InstalledApp.ID? {
        didSet { if oldValue != selectedAppID { loadLeftovers() } }
    }
    var leftovers: [Leftover] = []
    var isLoadingLeftovers = false
    var isUninstalling = false
    var lastResult: CleanResult?

    private var leftoverTask: Task<Void, Never>?

    var filteredApps: [InstalledApp] {
        searchText.isEmpty ? apps : apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.bundleID?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var selectedApp: InstalledApp? { apps.first { $0.id == selectedAppID } }
    var selectedLeftoverSize: Int64 { leftovers.filter(\.isSelected).reduce(0) { $0 + $1.size } }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        apps = await AppInventoryService.installedApps()
        isLoading = false
    }

    func loadLeftovers() {
        leftoverTask?.cancel()
        leftovers = []
        lastResult = nil
        guard let app = selectedApp else { return }
        isLoadingLeftovers = true
        leftoverTask = Task {
            let found = await AppInventoryService.leftovers(for: app)
            guard !Task.isCancelled else { return }
            leftovers = found
            isLoadingLeftovers = false
        }
    }

    func toggleLeftover(_ id: Leftover.ID) {
        guard let i = leftovers.firstIndex(where: { $0.id == id }) else { return }
        leftovers[i].isSelected.toggle()
    }

    func isRunning(_ app: InstalledApp) -> Bool { AppInventoryService.isRunning(app) }

    func uninstallSelected() async {
        guard let app = selectedApp else { return }
        isUninstalling = true
        let result = await AppInventoryService.uninstall(app, leftovers: leftovers.filter(\.isSelected))
        lastResult = result
        isUninstalling = false
        if !result.failures.contains(where: { $0.url == app.url }) {
            apps.removeAll { $0.id == app.id }
            selectedAppID = nil
        }
    }
}
