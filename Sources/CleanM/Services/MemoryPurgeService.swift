import Foundation

enum MemoryPurgeError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Authorization was cancelled."
        case .failed(let message): return message
        }
    }
}

enum MemoryPurgeService {
    /// Runs `/usr/sbin/purge` with administrator privileges. macOS shows its own authentication dialog,
    /// so CleanM never sees the password. The AppleScript runs on a dedicated thread so the UI stays responsive.
    static func purge() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let thread = Thread {
                let source = "do shell script \"/usr/sbin/purge\" with administrator privileges"
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(throwing: MemoryPurgeError.failed("Could not create AppleScript."))
                    return
                }
                var errorInfo: NSDictionary?
                script.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
                    if code == -128 {
                        continuation.resume(throwing: MemoryPurgeError.cancelled)
                    } else {
                        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "purge failed (\(code))."
                        continuation.resume(throwing: MemoryPurgeError.failed(message))
                    }
                } else {
                    continuation.resume()
                }
            }
            thread.name = "CleanM.purge"
            thread.start()
        }
    }
}
