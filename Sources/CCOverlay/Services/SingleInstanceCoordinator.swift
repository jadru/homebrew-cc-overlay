import AppKit
import Darwin
import Foundation

/// Keeps independently built or Homebrew-upgraded copies from presenting more
/// than one overlay. The lock lives outside the app bundle so every copy shares
/// the same arbitration point.
///
/// ponytail: This deliberately uses one app-wide lock because CC-Overlay owns
/// a single global overlay. Split the lock only if independent overlays become
/// a supported product feature.
@MainActor
final class SingleInstanceCoordinator {
    private let lockURL: URL
    private var lockFileDescriptor: Int32 = -1

    init(lockURL: URL? = nil) {
        self.lockURL = lockURL ?? Self.defaultLockURL()
    }

    deinit {
        if lockFileDescriptor >= 0 {
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
        }
    }

    /// Claims the shared instance lock. An ordinary second launch foregrounds
    /// the existing copy. A deliberate in-app update replaces that copy before
    /// claiming the lock, preserving the existing update handoff contract.
    func claimOrActivateExisting(isUpdateHandoff: Bool) -> Bool {
        if claimLock() {
            // Previous releases did not participate in the lock. If this is
            // the first upgraded copy, it must still replace those processes
            // before either can create a second floating overlay.
            terminateOtherInstances()
            guard waitForOtherInstancesToTerminate() else {
                activateExistingInstance()
                release()
                return false
            }
            return true
        }

        if isUpdateHandoff {
            terminateOtherInstances()
            if waitForLockRelease() {
                return true
            }
        }

        activateExistingInstance()
        closeLockFile()
        return false
    }

    func release() {
        guard lockFileDescriptor >= 0 else { return }
        flock(lockFileDescriptor, LOCK_UN)
        closeLockFile()
    }

    private func claimLock() -> Bool {
        guard openLockFileIfNeeded() else { return false }
        return flock(lockFileDescriptor, LOCK_EX | LOCK_NB) == 0
    }

    private func waitForLockRelease() -> Bool {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if claimLock() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    private func waitForOtherInstancesToTerminate() -> Bool {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if otherInstances.isEmpty {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return otherInstances.isEmpty
    }

    private func openLockFileIfNeeded() -> Bool {
        guard lockFileDescriptor < 0 else { return true }

        let directoryURL = lockURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            AppLogger.ui.error("Could not create the single-instance lock directory: \(error.localizedDescription)")
            return false
        }

        lockFileDescriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFileDescriptor >= 0 else {
            AppLogger.ui.error("Could not open the single-instance lock file")
            return false
        }
        return true
    }

    private func closeLockFile() {
        guard lockFileDescriptor >= 0 else { return }
        close(lockFileDescriptor)
        lockFileDescriptor = -1
    }

    private func terminateOtherInstances() {
        for application in otherInstances {
            application.terminate()
        }
    }

    private func activateExistingInstance() {
        otherInstances.first?.activate(options: [])
    }

    private var otherInstances: [NSRunningApplication] {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return [] }
        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessID && !$0.isTerminated }
    }

    private static func defaultLockURL() -> URL {
        let applicationSupportURL = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent("CC-Overlay", isDirectory: true)
            .appendingPathComponent("cc-overlay.instance.lock")
    }
}
