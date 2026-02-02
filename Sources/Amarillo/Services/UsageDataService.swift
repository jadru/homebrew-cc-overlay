import Foundation
import Observation

@Observable
@MainActor
final class UsageDataService {
    private(set) var aggregatedUsage: AggregatedUsage = .empty
    private(set) var oauthUsage: OAuthUsageStatus = .empty
    private(set) var detectedPlan: String?
    private(set) var isLoading = false
    private(set) var lastRefresh: Date?
    private(set) var error: String?

    private var refreshTimer: Timer?
    private var fileWatcher: FileWatcher?
    private let claudeProjectsPath: String
    private let apiService = AnthropicAPIService()

    init(claudeProjectsPath: String = AppConstants.claudeProjectsPath) {
        self.claudeProjectsPath = claudeProjectsPath
    }

    /// The primary usage percentage. Prefers API-sourced data when available.
    var usedPercentage: Double {
        if oauthUsage.isAvailable {
            return oauthUsage.usedPercentage
        }
        return 0
    }

    var remainingPercentage: Double {
        100.0 - usedPercentage
    }

    var hasAPIData: Bool {
        oauthUsage.isAvailable
    }

    func startMonitoring(interval: TimeInterval = AppConstants.defaultRefreshInterval) {
        refresh()

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        fileWatcher?.stop()
        fileWatcher = FileWatcher(directory: claudeProjectsPath) { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }

        // Detect plan from Keychain on first launch
        Task {
            detectedPlan = await apiService.detectedSubscriptionType()
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        fileWatcher?.stop()
        fileWatcher = nil
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        stopMonitoring()
        startMonitoring(interval: interval)
    }

    func refresh() {
        isLoading = true

        // Refresh JSONL data synchronously
        do {
            let allEntries = try discoverAndParseAllSessions()
            aggregatedUsage = UsageCalculator.aggregate(entries: allEntries)
            lastRefresh = Date()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }

        // Fetch API rate limit asynchronously
        Task {
            await fetchRateLimit()
            self.isLoading = false
        }
    }

    private func fetchRateLimit() async {
        do {
            let usage = try await apiService.fetchUsage()
            self.oauthUsage = usage
            self.error = nil
        } catch is KeychainHelper.KeychainError {
            // No credentials — silently fall back to JSONL-only mode
        } catch {
            // API call failed — keep existing data if available
            if !oauthUsage.isAvailable {
                self.error = error.localizedDescription
            }
        }
    }

    private func discoverAndParseAllSessions() throws -> [ParsedUsageEntry] {
        let fm = FileManager.default
        let projectsURL = URL(fileURLWithPath: claudeProjectsPath)

        guard fm.fileExists(atPath: projectsURL.path) else { return [] }

        var allEntries: [ParsedUsageEntry] = []

        let projectDirs = try fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue
            else { continue }

            let files: [URL]
            do {
                files = try fm.contentsOfDirectory(
                    at: projectDir,
                    includingPropertiesForKeys: [.contentModificationDateKey]
                ).filter { $0.pathExtension == "jsonl" }
            } catch {
                continue
            }

            // Only parse files modified within the last 24 hours for performance
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            for file in files {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < oneDayAgo
                {
                    continue
                }

                if let entries = try? JSONLParser.parseSessionFile(at: file) {
                    allEntries.append(contentsOf: entries)
                }
            }
        }

        return allEntries
    }
}
