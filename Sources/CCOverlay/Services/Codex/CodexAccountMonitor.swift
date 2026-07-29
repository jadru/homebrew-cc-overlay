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
            let results = await withTaskGroup(
                of: (CodexAccountProfile, Result<CodexAccountUsageSnapshot, Error>).self,
                returning: [(CodexAccountProfile, Result<CodexAccountUsageSnapshot, Error>)].self
            ) { group in
                for profile in batch {
                    group.addTask {
                        do {
                            let snapshot = try await CodexAccountUsageReader.fetch(
                                profile: profile,
                                binaryPath: binaryPath
                            )
                            return (profile, .success(snapshot))
                        } catch {
                            return (profile, .failure(error))
                        }
                    }
                }

                var values: [(CodexAccountProfile, Result<CodexAccountUsageSnapshot, Error>)] = []
                for await result in group { values.append(result) }
                return values
            }

            for (profile, result) in results {
                refreshingProfileIDs.remove(profile.id)
                switch result {
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
        do {
            snapshots[profileID] = try await CodexAccountUsageReader.fetch(
                profile: profile,
                binaryPath: binaryPath
            )
            errors[profileID] = nil
        } catch {
            errors[profileID] = error.localizedDescription
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
