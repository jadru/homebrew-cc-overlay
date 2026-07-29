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

// MARK: - UpdateService

@Observable
@MainActor
final class UpdateService {
    var updateState: UpdateStatus = .idle

    private var settings: AppSettings?
    private var timer: Timer?
    private var initialCheckTask: Task<Void, Never>?

    private struct CommandResult {
        let terminationStatus: Int32
        let standardOutput: String
        let standardError: String

        var combinedOutput: String {
            [standardOutput, standardError]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    nonisolated static func resolvedCurrentVersion(bundleVersion: String?, fallbackVersion: String) -> String {
        guard let bundleVersion = bundleVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleVersion.isEmpty
        else {
            return fallbackVersion
        }
        return bundleVersion
    }

    nonisolated static func installedVersionSatisfiesTarget(
        processSucceeded: Bool,
        installedVersion: String?,
        targetVersion: String
    ) -> Bool {
        guard processSucceeded, let installedVersion else { return false }
        return compareVersions(installedVersion, targetVersion) != .orderedAscending
    }

    nonisolated static func homebrewCandidatePaths(home: String) -> [String] {
        [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "\(home)/.linuxbrew/bin/brew",
            "/home/linuxbrew/.linuxbrew/bin/brew",
        ]
    }

    nonisolated static func firstExecutablePath(
        in candidates: [String],
        isExecutable: (String) -> Bool
    ) -> String? {
        candidates.first(where: isExecutable)
    }

    static var currentAppVersion: String {
        resolvedCurrentVersion(
            bundleVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            fallbackVersion: AppConstants.version
        )
    }

    nonisolated static func versionFromReleaseURL(_ url: URL?) -> String? {
        guard let components = url?.pathComponents,
              let tagIndex = components.firstIndex(of: "tag"),
              components.indices.contains(tagIndex + 1)
        else {
            return nil
        }

        let tag = components[tagIndex + 1]
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    nonisolated static func checkFailureState(presentsErrors: Bool) -> UpdateStatus {
        presentsErrors
            ? .error(message: "GitHub release check failed. Try again later.")
            : .idle
    }

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
        await performCheck(presentsErrors: true)
    }

    /// Install update via Homebrew without depending on a GUI app's inherited PATH.
    func installUpdate() {
        guard case .updateAvailable(let version) = updateState else { return }
        updateState = .installing

        Task.detached { [weak self] in
            do {
                guard let homebrewPath = Self.homebrewExecutablePath() else {
                    await MainActor.run { [weak self] in
                        self?.updateState = .error(
                            message: "Homebrew was not found. Download v\(version) from GitHub Releases or install Homebrew, then retry."
                        )
                    }
                    return
                }

                let steps = [
                    ["tap", AppConstants.homebrewTap],
                    ["update"],
                    ["upgrade", AppConstants.homebrewFormula],
                ]
                var output = ""
                var status: Int32 = 0

                for arguments in steps {
                    let result = try Self.runCommand(executablePath: homebrewPath, arguments: arguments)
                    if !result.combinedOutput.isEmpty {
                        output += result.combinedOutput + "\n"
                    }
                    status = result.terminationStatus
                    if status != 0 { break }
                }

                let installedVersion = status == 0
                    ? Self.installedAppMetadata(homebrewExecutablePath: homebrewPath).version
                    : nil
                await MainActor.run { [weak self] in
                    if Self.installedVersionSatisfiesTarget(
                        processSucceeded: status == 0,
                        installedVersion: installedVersion,
                        targetVersion: version
                    ) {
                        self?.updateState = .readyToRestart(version: version)
                    } else {
                        let installed = installedVersion.map { " Installed version: \($0)." } ?? ""
                        let detail = Self.conciseCommandOutput(output)
                        self?.updateState = .error(
                            message: "Update did not install v\(version).\(installed) \(detail)"
                        )
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
        guard case .readyToRestart(let version) = updateState else { return }

        Task.detached { [weak self] in
            let failure = Self.launchInstalledApp(expectedVersion: version)
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

        await performCheck(presentsErrors: false)
    }

    private func performCheck(presentsErrors: Bool) async {
        updateState = .checking

        let urlString = "https://github.com/\(AppConstants.githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            updateState = Self.checkFailureState(presentsErrors: presentsErrors)
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("text/html", forHTTPHeaderField: "Accept")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let remoteVersion = Self.versionFromReleaseURL(httpResponse.url)
            else {
                updateState = Self.checkFailureState(presentsErrors: presentsErrors)
                return
            }

            settings?.lastUpdateCheck = Date()

            if Self.isNewerVersion(remoteVersion, than: Self.currentAppVersion) {
                updateState = .updateAvailable(version: remoteVersion)
            } else {
                updateState = .upToDate
            }
        } catch {
            updateState = Self.checkFailureState(presentsErrors: presentsErrors)
        }
    }

    /// Resolves Homebrew's stable opt prefix after an upgrade, then opens that bundle.
    nonisolated private static func installedAppMetadata(
        homebrewExecutablePath brewPath: String? = nil
    ) -> (url: URL?, version: String?) {
        guard let homebrewExecutablePath = brewPath ?? homebrewExecutablePath() else {
            return (nil, nil)
        }
        do {
            let result = try runCommand(
                executablePath: homebrewExecutablePath,
                arguments: ["--prefix", AppConstants.homebrewFormula]
            )
            guard result.terminationStatus == 0 else {
                return (nil, nil)
            }

            guard let prefix = result.standardOutput
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .first(where: { $0.hasPrefix("/") })
            else {
                return (nil, nil)
            }
            let appURL = URL(fileURLWithPath: prefix, isDirectory: true)
                .appendingPathComponent("CC-Overlay.app", isDirectory: true)
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                return (nil, nil)
            }

            let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
            guard let data = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dictionary = plist as? [String: Any],
                  let version = dictionary["CFBundleShortVersionString"] as? String
            else {
                return (appURL, nil)
            }

            return (appURL, version)
        } catch {
            return (nil, nil)
        }
    }

    nonisolated private static func homebrewExecutablePath() -> String? {
        firstExecutablePath(
            in: homebrewCandidatePaths(home: FileManager.default.homeDirectoryForCurrentUser.path),
            isExecutable: FileManager.default.isExecutableFile(atPath:)
        )
    }

    nonisolated private static func runCommand(
        executablePath: String,
        arguments: [String]
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = commandEnvironment(executablePath: executablePath)

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: ""
        )
    }

    nonisolated private static func commandEnvironment(executablePath: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let homebrewBin = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
        let inheritedPaths = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        let paths = [homebrewBin, "/usr/bin", "/bin", "/usr/sbin", "/sbin"] + inheritedPaths
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["PATH"] = paths.reduce(into: [String]()) { result, path in
            if !result.contains(path) { result.append(path) }
        }.joined(separator: ":")
        return environment
    }

    nonisolated private static func conciseCommandOutput(_ output: String) -> String {
        let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "Homebrew returned no error details." }
        return String(normalized.suffix(600))
    }

    nonisolated private static func launchInstalledApp(expectedVersion: String) -> String? {
        let metadata = installedAppMetadata()
        guard let appURL = metadata.url else {
            return "Updated app bundle was not found."
        }
        guard installedVersionSatisfiesTarget(
            processSucceeded: true,
            installedVersion: metadata.version,
            targetVersion: expectedVersion
        ) else {
            return "Installed app version does not match v\(expectedVersion)."
        }

        do {
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
    nonisolated private static func isNewerVersion(_ remote: String, than current: String) -> Bool {
        compareVersions(remote, current) == .orderedDescending
    }

    nonisolated private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = lhs.split(separator: ".").compactMap { Int($0) }
        let rhsParts = rhs.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(lhsParts.count, rhsParts.count) {
            let lhsValue = i < lhsParts.count ? lhsParts[i] : 0
            let rhsValue = i < rhsParts.count ? rhsParts[i] : 0
            if lhsValue > rhsValue { return .orderedDescending }
            if lhsValue < rhsValue { return .orderedAscending }
        }
        return .orderedSame
    }
}
