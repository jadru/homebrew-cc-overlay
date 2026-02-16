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

    func configure(settings: AppSettings) {
        self.settings = settings
    }

    func startMonitoring() {
        // Initial check after 3-second delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            await scheduledCheck()
        }

        // Periodic check every 24h
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.updateCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.scheduledCheck()
            }
        }
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
            process.arguments = ["-l", "-c", "brew update && brew upgrade cc-overlay"]

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

    /// Restart the app via brew services.
    func restartApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", "brew services restart cc-overlay"]

        do {
            try process.run()
            // Don't waitUntilExit — brew will SIGTERM us
        } catch {
            updateState = .error(message: "Restart failed: \(error.localizedDescription)")
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
