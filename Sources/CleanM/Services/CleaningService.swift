import Foundation

struct CleanFailure: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let message: String
}

struct CleanResult: Sendable {
    var freedBytes: Int64 = 0
    var removedCount: Int = 0
    var failures: [CleanFailure] = []
    var permanently: Bool = false

    mutating func merge(_ other: CleanResult) {
        freedBytes += other.freedBytes
        removedCount += other.removedCount
        failures += other.failures
    }

    var summary: String {
        let verb = permanently ? "Removed" : "Moved to Trash"
        var text = "\(verb) \(removedCount) item\(removedCount == 1 ? "" : "s") · \(ByteFormat.string(freedBytes))"
        if !failures.isEmpty { text += " · \(failures.count) skipped" }
        return text
    }
}

struct CleanRequest: Sendable {
    let url: URL
    let size: Int64
}

enum CleaningService {
    /// Removes the given items after re-validating every path against `SafetyWhitelist`.
    /// - Parameter permanently: `false` (default) moves items to the Trash; `true` deletes them.
    static func clean(_ requests: [CleanRequest],
                      permanently: Bool = false,
                      allowApplications: Bool = false) async -> CleanResult {
        let runningIDs = SafetyWhitelist.runningBundleIDs()
        let runningPaths = SafetyWhitelist.runningBundlePaths()

        return await Task.detached(priority: .userInitiated) {
            var result = CleanResult(permanently: permanently)
            let fm = FileManager.default
            for request in requests {
                if Task.isCancelled { break }
                let verdict = SafetyWhitelist.verdict(for: request.url,
                                                      allowApplications: allowApplications,
                                                      runningIDs: runningIDs,
                                                      runningPaths: runningPaths)
                guard verdict.isAllowed else {
                    result.failures.append(CleanFailure(url: request.url, message: verdict.reason ?? "Not allowed"))
                    continue
                }
                let target = SafetyWhitelist.canonical(request.url)
                guard fm.fileExists(atPath: target.path) || isDanglingSymlink(target) else {
                    // Already gone — nothing to do, not an error.
                    continue
                }
                do {
                    if permanently {
                        try fm.removeItem(at: target)
                    } else {
                        try fm.trashItem(at: target, resultingItemURL: nil)
                    }
                    result.freedBytes += request.size
                    result.removedCount += 1
                } catch {
                    result.failures.append(CleanFailure(url: request.url, message: describe(error, url: target)))
                }
            }
            return result
        }.value
    }

    private static func isDanglingSymlink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    static func describe(_ error: Error, url: URL) -> String {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain,
           ns.code == NSFileWriteNoPermissionError || ns.code == NSFileReadNoPermissionError {
            let owner = (try? FileManager.default.attributesOfItem(atPath: url.path)[.ownerAccountName] as? String) ?? nil
            if owner == "root" {
                return "Owned by root — CleanM can't remove it without admin rights. Drag it to the Trash in Finder instead."
            }
            return "Permission denied. Grant Full Disk Access or remove it in Finder."
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError, underlying.domain == NSPOSIXErrorDomain,
           underlying.code == Int(EPERM) || underlying.code == Int(EACCES) {
            return "Operation not permitted (protected by macOS)."
        }
        return ns.localizedDescription
    }
}
