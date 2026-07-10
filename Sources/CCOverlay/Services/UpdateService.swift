import AppKit
import Foundation

// MARK: - Update Status

enum UpdateStatus: Equatable {
    case idle, checking, upToDate
    case updateAvailable(version: String)
    case installing
    case readyToRestart(version: String)
    case error(message: String)
}

// MARK: - GitHub Release Model

private struct GitHubRelease: Codable {
    let tag_name: String
    let body: String?
}

// MARK: - UpdateService

@Observable
@MainActor
final class UpdateService {
    var updateState: UpdateStatus = .idle

    private var settings: AppSettings?
    private var timer: Timer?
    private var initialCheckTask: Task<Void, Never>?

    func configure(settings: AppSettings) {
        self.settings = settings
    }

    func startMonitoring() {
        stopMonitoring()

        // Initial check after 3-second delay
        initialCheckTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await scheduledCheck()
        }

        // Periodic check every 24h
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.updateCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.scheduledCheck()
            }
        }
    }

    func stopMonitoring() {
        initialCheckTask?.cancel()
        initialCheckTask = nil
        timer?.invalidate()
        timer = nil
    }

    /// Manual check triggered from Settings — skips schedule/enabled guards.
    func checkForUpdates() async {
        await performCheck()
    }

    /// Install update via brew.
    func installUpdate() {
        guard case .updateAvailable(let version) = updateState else { return }
        updateState = .installing

        Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [
                "-l",
                "-c",
                "brew tap \(AppConstants.homebrewTap) && brew update && brew upgrade \(AppConstants.homebrewFormula)"
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let status = process.terminationStatus
                await MainActor.run { [weak self] in
                    if status == 0 {
                        self?.updateState = .readyToRestart(version: version)
                    } else {
                        let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                        self?.updateState = .error(message: "brew upgrade failed: \(output)")
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.updateState = .error(message: error.localizedDescription)
                }
            }
        }
    }

    /// Dismiss the update banner.
    func dismiss() {
        updateState = .idle
    }

    /// Restart the freshly upgraded app bundle without creating a Homebrew service.
    func restartApp() {
        Task.detached { [weak self] in
            let failure = Self.launchInstalledApp()
            await MainActor.run { [weak self] in
                if let failure {
                    self?.updateState = .error(message: "Restart failed: \(failure)")
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // MARK: - Private

    private func scheduledCheck() async {
        guard let settings, settings.autoUpdateEnabled else { return }

        // Skip if checked within the interval
        if let last = settings.lastUpdateCheck,
           Date().timeIntervalSince(last) < AppConstants.updateCheckInterval {
            return
        }

        await performCheck()
    }

    private func performCheck() async {
        updateState = .checking

        let urlString = "https://api.github.com/repos/\(AppConstants.githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            updateState = .error(message: "Invalid URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                updateState = .error(message: "GitHub API returned non-200")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name

            settings?.lastUpdateCheck = Date()

            if isNewerVersion(remoteVersion, than: AppConstants.version) {
                updateState = .updateAvailable(version: remoteVersion)
            } else {
                updateState = .upToDate
            }
        } catch {
            updateState = .error(message: error.localizedDescription)
        }
    }

    /// Resolves Homebrew's stable opt prefix after an upgrade, then opens that bundle.
    nonisolated private static func launchInstalledApp() -> String? {
        let prefixProcess = Process()
        prefixProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        prefixProcess.arguments = ["-l", "-c", "brew --prefix \(AppConstants.homebrewFormula)"]

        let prefixPipe = Pipe()
        prefixProcess.standardOutput = prefixPipe
        prefixProcess.standardError = Pipe()

        do {
            try prefixProcess.run()
            let data = prefixPipe.fileHandleForReading.readDataToEndOfFile()
            prefixProcess.waitUntilExit()

            guard prefixProcess.terminationStatus == 0 else {
                return "Could not resolve the installed Homebrew app."
            }

            let prefix = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let appURL = URL(fileURLWithPath: prefix, isDirectory: true)
                .appendingPathComponent("CC-Overlay.app", isDirectory: true)
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                return "Updated app bundle was not found."
            }

            let openProcess = Process()
            openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProcess.arguments = ["-n", appURL.path]
            try openProcess.run()
            openProcess.waitUntilExit()
            return openProcess.terminationStatus == 0 ? nil : "Could not launch the updated app."
        } catch {
            return error.localizedDescription
        }
    }

    /// Semantic version comparison: returns true if `remote` > `current`.
    private func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}
