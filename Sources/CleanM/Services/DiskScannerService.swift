import Foundation
import UniformTypeIdentifiers

struct ScanProgress: Sendable {
    var label: String
    var completedUnits: Int
    var totalUnits: Int
    var bytesFound: Int64

    var fraction: Double { totalUnits == 0 ? 0 : Double(completedUnits) / Double(totalUnits) }
}

/// Walks the file system. Heavy lifting is done in `nonisolated` helpers so that task-group children
/// really run in parallel; the actor only serialises shared progress bookkeeping.
actor DiskScannerService {
    static let shared = DiskScannerService()

    private static let sizeKeys: [URLResourceKey] = [
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey,
        .isSymbolicLinkKey, .contentAccessDateKey, .isRegularFileKey, .isPackageKey,
    ]

    // MARK: Size measurement

    /// Allocated size of a file or the recursive size of a directory. Symlinks are never followed.
    nonisolated static func allocatedSize(of url: URL) -> Int64 {
        let keys = Set(sizeKeys)
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if values.isSymbolicLink == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard values.isDirectory == true else {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: sizeKeys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var counter = 0
        for case let child as URL in enumerator {
            counter += 1
            if counter % 512 == 0, Task.isCancelled { return total }
            guard let v = try? child.resourceValues(forKeys: keys) else { continue }
            if v.isDirectory == true && v.isSymbolicLink != true { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// First-level children of `root` with their recursive sizes.
    nonisolated static func childItems(of root: URL, excluding: Set<String> = []) -> [ScanItem] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else { return [] }

        var items: [ScanItem] = []
        let running = SafetyWhitelist.runningBundleIDs()
        for child in children {
            if Task.isCancelled { break }
            let name = child.lastPathComponent
            if excluding.contains(name) || name == ".DS_Store" || name == ".localized" { continue }
            // Skip anything we would never be allowed to remove so the UI only offers safe items.
            guard SafetyWhitelist.verdict(for: child, runningIDs: running).isAllowed else { continue }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDir = values?.isDirectory == true && values?.isSymbolicLink != true
            let size = allocatedSize(of: child)
            guard size > 0 || !isDir else { continue }
            items.append(ScanItem(url: child, size: size, isDirectory: isDir))
        }
        return items.sorted { $0.size > $1.size }
    }

    // MARK: Junk

    private var junkProgress = ScanProgress(label: "", completedUnits: 0, totalUnits: 0, bytesFound: 0)

    private func resetProgress(total: Int) {
        junkProgress = ScanProgress(label: "Preparing…", completedUnits: 0, totalUnits: total, bytesFound: 0)
    }

    private func advance(label: String, bytes: Int64) -> ScanProgress {
        junkProgress.completedUnits += 1
        junkProgress.bytesFound += bytes
        junkProgress.label = label
        return junkProgress
    }

    /// Scans junk categories concurrently.
    func scanJunk(_ kinds: [JunkKind],
                  progress: @escaping @Sendable (ScanProgress) -> Void) async -> [JunkCategory] {
        resetProgress(total: kinds.count)
        progress(junkProgress)

        let results = await withTaskGroup(of: JunkCategory.self, returning: [JunkCategory].self) { group in
            for kind in kinds {
                group.addTask {
                    let items = kind.roots.flatMap { Self.childItems(of: $0, excluding: kind.excludedChildNames) }
                    return JunkCategory(kind: kind, items: items)
                }
            }
            var collected: [JunkCategory] = []
            for await category in group {
                collected.append(category)
                let snapshot = advance(label: category.kind.title, bytes: category.totalSize)
                progress(snapshot)
            }
            return collected
        }
        return kinds.compactMap { kind in results.first { $0.kind == kind } }
    }

    // MARK: Large & Old

    static var largeAndOldRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Downloads", "Documents", "Desktop", "Movies"].map { home.appendingPathComponent($0, isDirectory: true) }
    }

    /// Minimum size for a file to be reported purely because it is old (keeps the list meaningful).
    static let oldFileMinimumSize: Int64 = 5 * 1_000_000

    nonisolated static func scanLargeOld(root: URL, onFile: (Int) -> Void) -> [LargeFile] {
        let keys = sizeKeys + [.contentTypeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let cutoff = LargeFile.oldCutoff
        var found: [LargeFile] = []
        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            if visited % 256 == 0 {
                if Task.isCancelled { break }
                onFile(visited)
            }
            guard let v = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if v.isSymbolicLink == true { continue }

            let isPackage = v.isPackage == true
            let isFile = v.isRegularFile == true
            guard isFile || isPackage else { continue }

            let size: Int64 = isPackage
                ? allocatedSize(of: url)
                : Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
            let access = v.contentAccessDate
            let isLarge = size >= LargeFile.largeThreshold
            let isOld = (access.map { $0 < cutoff } ?? false) && size >= oldFileMinimumSize
            guard isLarge || isOld else { continue }

            found.append(LargeFile(url: url, size: size, lastAccess: access, kind: FileKind.classify(v.contentType)))
        }
        return found
    }

    func scanLargeAndOld(roots: [URL] = DiskScannerService.largeAndOldRoots,
                         progress: @escaping @Sendable (ScanProgress) -> Void) async -> [LargeFile] {
        let total = roots.count
        progress(ScanProgress(label: "Preparing…", completedUnits: 0, totalUnits: total, bytesFound: 0))

        return await withTaskGroup(of: [LargeFile].self, returning: [LargeFile].self) { group in
            for root in roots {
                group.addTask {
                    Self.scanLargeOld(root: root) { visited in
                        progress(ScanProgress(label: "\(root.lastPathComponent) — \(visited) files",
                                              completedUnits: 0, totalUnits: 0, bytesFound: 0))
                    }
                }
            }
            var all: [LargeFile] = []
            var done = 0
            for await files in group {
                done += 1
                all.append(contentsOf: files)
                progress(ScanProgress(label: "Checked \(done) of \(total) folders",
                                      completedUnits: done, totalUnits: total,
                                      bytesFound: all.reduce(0) { $0 + $1.size }))
            }
            return all.sorted { $0.size > $1.size }
        }
    }
}
