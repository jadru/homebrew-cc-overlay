import Foundation
import Observation

@Observable
@MainActor
final class CodexAccountMonitor {
    private(set) var snapshots: [UUID: CodexAccountUsageSnapshot] = [:]
    private(set) var errors: [UUID: String] = [:]
    private(set) var refreshingProfileIDs: Set<UUID> = []

    private let profileStore: CodexAccountProfileStore
    private let binaryPathProvider: @MainActor () -> String?
    private let maximumConcurrentRefreshes: Int
    private var monitorTask: Task<Void, Never>?
    private var selectedRefreshInterval: TimeInterval = 60
    private let backgroundRefreshInterval: TimeInterval = 5 * 60
    private var transcriptFileStates: [UUID: [String: CodexTranscriptTokenScanner.FileState]] = [:]

    init(
        profileStore: CodexAccountProfileStore,
        maximumConcurrentRefreshes: Int = 3,
        binaryPathProvider: @escaping @MainActor () -> String? = { CodexDetector.findBinary() }
    ) {
        self.profileStore = profileStore
        self.maximumConcurrentRefreshes = max(maximumConcurrentRefreshes, 1)
        self.binaryPathProvider = binaryPathProvider
    }

    var selectedSnapshot: CodexAccountUsageSnapshot? {
        profileStore.selectedProfileID.flatMap { snapshots[$0] }
    }

    var recommendedProfile: CodexAccountProfile? {
        profileStore.enabledProfiles
            .filter { snapshots[$0.id] != nil }
            .max { lhs, rhs in
                (snapshots[lhs.id]?.headroom ?? 0) < (snapshots[rhs.id]?.headroom ?? 0)
            }
    }

    var availableProfileCount: Int {
        profileStore.enabledProfiles.filter { snapshots[$0.id] != nil }.count
    }

    func snapshot(for profileID: UUID) -> CodexAccountUsageSnapshot? {
        snapshots[profileID]
    }

    func startMonitoring(selectedInterval: TimeInterval = 60) {
        stopMonitoring()
        selectedRefreshInterval = max(selectedInterval, 15)
        monitorTask = Task { [weak self] in
            guard let self else { return }
            await refreshAll(force: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await refreshAll(force: false)
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        startMonitoring(selectedInterval: interval)
    }

    func refreshAll(force: Bool = true, now: Date = Date()) async {
        let enabledProfiles = profileStore.enabledProfiles
        let activeIDs = Set(enabledProfiles.map(\.id))
        snapshots = snapshots.filter { activeIDs.contains($0.key) }
        errors = errors.filter { activeIDs.contains($0.key) }

        guard let binaryPath = binaryPathProvider() else {
            for profile in enabledProfiles {
                errors[profile.id] = "Codex CLI is not installed."
            }
            return
        }

        let dueProfiles = enabledProfiles.filter { profile in
            guard !force, let lastRefresh = snapshots[profile.id]?.fetchedAt else { return true }
            let interval = profile.id == profileStore.selectedProfileID
                ? selectedRefreshInterval
                : backgroundRefreshInterval
            return now.timeIntervalSince(lastRefresh) >= interval
        }

        for batch in Self.refreshBatches(
            profiles: dueProfiles,
            maximumConcurrent: maximumConcurrentRefreshes
        ) {
            refreshingProfileIDs.formUnion(batch.map(\.id))
            let knownTranscriptStates = transcriptFileStates
            let results = await withTaskGroup(
                of: (
                    CodexAccountProfile,
                    Result<CodexAccountUsageSnapshot, Error>,
                    Result<CodexTranscriptTokenScanner.ScanResult, Error>
                ).self,
                returning: [(
                    CodexAccountProfile,
                    Result<CodexAccountUsageSnapshot, Error>,
                    Result<CodexTranscriptTokenScanner.ScanResult, Error>
                )].self
            ) { group in
                for profile in batch {
                    let priorTranscriptStates = knownTranscriptStates[profile.id] ?? [:]
                    group.addTask {
                        let transcriptResult: Result<CodexTranscriptTokenScanner.ScanResult, Error>
                        do {
                            transcriptResult = .success(try CodexTranscriptTokenScanner.scan(
                                codexHome: profile.codexHome,
                                previousStates: priorTranscriptStates
                            ))
                        } catch {
                            transcriptResult = .failure(error)
                        }

                        do {
                            let snapshot = try await CodexAccountUsageReader.fetch(
                                profile: profile,
                                binaryPath: binaryPath
                            )
                            return (profile, .success(snapshot), transcriptResult)
                        } catch {
                            return (profile, .failure(error), transcriptResult)
                        }
                    }
                }

                var values: [(
                    CodexAccountProfile,
                    Result<CodexAccountUsageSnapshot, Error>,
                    Result<CodexTranscriptTokenScanner.ScanResult, Error>
                )] = []
                for await result in group { values.append(result) }
                return values
            }

            for (profile, result, transcriptResult) in results {
                refreshingProfileIDs.remove(profile.id)
                let transcript = try? transcriptResult.get()
                if let transcript {
                    transcriptFileStates[profile.id] = transcript.fileStates
                }
                switch Self.mergedSnapshot(
                    profileID: profile.id,
                    accountResult: result,
                    transcript: transcript,
                    fetchedAt: now
                ) {
                case .success(let snapshot):
                    snapshots[profile.id] = snapshot
                    errors[profile.id] = nil
                case .failure(let error):
                    errors[profile.id] = error.localizedDescription
                }
            }
        }
    }

    func refresh(_ profileID: UUID) async {
        guard let profile = profileStore.profiles.first(where: { $0.id == profileID }),
              profile.isEnabled
        else { return }
        guard let binaryPath = binaryPathProvider() else {
            errors[profileID] = "Codex CLI is not installed."
            return
        }

        refreshingProfileIDs.insert(profileID)
        defer { refreshingProfileIDs.remove(profileID) }
        let transcriptResult = try? CodexTranscriptTokenScanner.scan(
            codexHome: profile.codexHome,
            previousStates: transcriptFileStates[profileID] ?? [:]
        )
        if let transcriptResult {
            transcriptFileStates[profileID] = transcriptResult.fileStates
        }

        let accountResult: Result<CodexAccountUsageSnapshot, Error>
        do {
            accountResult = .success(try await CodexAccountUsageReader.fetch(
                profile: profile,
                binaryPath: binaryPath
            ))
        } catch {
            accountResult = .failure(error)
        }

        switch Self.mergedSnapshot(
            profileID: profileID,
            accountResult: accountResult,
            transcript: transcriptResult,
            fetchedAt: Date()
        ) {
        case .success(let snapshot):
            snapshots[profileID] = snapshot
            errors[profileID] = nil
        case .failure(let error):
            errors[profileID] = error.localizedDescription
        }
    }

    nonisolated private static func mergedSnapshot(
        profileID: UUID,
        accountResult: Result<CodexAccountUsageSnapshot, Error>,
        transcript: CodexTranscriptTokenScanner.ScanResult?,
        fetchedAt: Date
    ) -> Result<CodexAccountUsageSnapshot, Error> {
        switch accountResult {
        case .success(let accountSnapshot):
            guard let transcript, transcript.hasTokenData else {
                return .success(accountSnapshot)
            }
            let activity = accountSnapshot.tokenActivity
            return .success(CodexAccountUsageSnapshot(
                profileID: accountSnapshot.profileID,
                planType: accountSnapshot.planType,
                primaryWindow: accountSnapshot.primaryWindow,
                secondaryWindow: accountSnapshot.secondaryWindow,
                tokenActivity: CodexTokenActivity(
                    lifetimeTokens: transcript.cumulativeTokens,
                    peakDailyTokens: activity.peakDailyTokens,
                    longestRunningTurnSeconds: activity.longestRunningTurnSeconds,
                    currentStreakDays: activity.currentStreakDays,
                    longestStreakDays: activity.longestStreakDays,
                    dailyBuckets: activity.dailyBuckets
                ),
                fetchedAt: accountSnapshot.fetchedAt
            ))
        case .failure(let accountError):
            guard let transcript, transcript.hasTokenData else {
                return .failure(accountError)
            }
            return .success(CodexAccountUsageSnapshot(
                profileID: profileID,
                planType: nil,
                primaryWindow: nil,
                secondaryWindow: nil,
                tokenActivity: CodexTokenActivity(
                    lifetimeTokens: transcript.cumulativeTokens,
                    peakDailyTokens: nil,
                    longestRunningTurnSeconds: nil,
                    currentStreakDays: nil,
                    longestStreakDays: nil,
                    dailyBuckets: []
                ),
                fetchedAt: fetchedAt
            ))
        }
    }

    nonisolated static func refreshBatches(
        profiles: [CodexAccountProfile],
        maximumConcurrent: Int
    ) -> [[CodexAccountProfile]] {
        let size = max(maximumConcurrent, 1)
        return stride(from: 0, to: profiles.count, by: size).map { start in
            Array(profiles[start..<min(start + size, profiles.count)])
        }
    }
}
