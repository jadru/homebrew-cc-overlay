import Foundation
import XCTest
@testable import CCOverlay

@MainActor
final class CodexAccountProfileStoreTests: XCTestCase {
    func testFreshInstallMigratesCurrentCodexHomeToDefaultProfile() {
        let defaults = makeDefaults()
        let store = CodexAccountProfileStore(defaults: defaults, userHome: "/Users/tester")

        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.selectedProfile?.displayName, "Default")
        XCTAssertEqual(store.selectedProfile?.codexHome, "/Users/tester/.codex")
    }

    func testStoreSupportsTwentyProfilesWithoutPairSpecificState() throws {
        let defaults = makeDefaults()
        let store = CodexAccountProfileStore(
            defaults: defaults,
            userHome: "/Users/tester",
            createsDefaultProfile: false
        )

        for index in 1...20 {
            try store.addProfile(
                displayName: "Account \(index)",
                codexHome: "/Users/tester/.codex-accounts/account-\(index)"
            )
        }

        XCTAssertEqual(store.profiles.count, 20)
        XCTAssertEqual(store.enabledProfiles.count, 20)
        XCTAssertEqual(store.selectedProfile?.displayName, "Account 20")
    }

    func testDuplicateCodexHomeIsRejectedAfterNormalization() throws {
        let defaults = makeDefaults()
        let store = CodexAccountProfileStore(
            defaults: defaults,
            userHome: "/Users/tester",
            createsDefaultProfile: false
        )
        try store.addProfile(displayName: "First", codexHome: "~/.codex-work")

        XCTAssertThrowsError(
            try store.addProfile(displayName: "Duplicate", codexHome: "/Users/tester/.codex-work/")
        ) { error in
            XCTAssertEqual(error as? CodexAccountProfileStore.StoreError, .duplicatePath)
        }
    }

    func testDisablingSelectedProfileSelectsAnotherEnabledProfile() throws {
        let defaults = makeDefaults()
        let store = CodexAccountProfileStore(defaults: defaults, userHome: "/Users/tester")
        let work = try store.addProfile(displayName: "Work", codexHome: "~/.codex-work")
        try store.select(work.id)

        try store.setEnabled(false, for: work.id)

        XCTAssertEqual(store.selectedProfile?.displayName, "Default")
    }

    func testRemovingProfileDoesNotDeleteItsCodexHome() throws {
        let defaults = makeDefaults()
        let store = CodexAccountProfileStore(
            defaults: defaults,
            userHome: "/Users/tester",
            createsDefaultProfile: false
        )
        let profile = try store.addProfile(displayName: "Client", codexHome: "~/.codex-client")

        try store.remove(profile.id)

        XCTAssertTrue(store.profiles.isEmpty)
        XCTAssertNil(store.selectedProfileID)

        let restoredStore = CodexAccountProfileStore(
            defaults: defaults,
            userHome: "/Users/tester"
        )
        XCTAssertTrue(restoredStore.profiles.isEmpty)
    }

    func testSuggestedPathUsesFirstAvailableAccountDirectory() throws {
        let defaults = makeDefaults()
        let store = CodexAccountProfileStore(
            defaults: defaults,
            userHome: "/Users/tester",
            createsDefaultProfile: false
        )
        let first = try store.addProfile(
            displayName: "First",
            codexHome: "/Users/tester/.codex-accounts/account-1"
        )
        _ = try store.addProfile(
            displayName: "Second",
            codexHome: "/Users/tester/.codex-accounts/account-2"
        )

        try store.remove(first.id)

        XCTAssertEqual(store.suggestedProfilePath, "/Users/tester/.codex-accounts/account-1")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "CodexAccountProfileStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

final class CodexAccountUsageTests: XCTestCase {
    func testTranscriptTokenScannerUsesLocalCodexCumulativeTokenCounts() throws {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-overlay-codex-token-scanner-\(UUID().uuidString)", isDirectory: true)
        let archive = codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
        let transcript = archive.appendingPathComponent("rollout.jsonl")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: codexHome) }

        try Data(tokenCountLine(total: 100).utf8).write(to: transcript)
        let initial = try CodexTranscriptTokenScanner.scan(
            codexHome: codexHome.path,
            previousStates: [:]
        )
        XCTAssertTrue(initial.hasTokenData)
        XCTAssertEqual(initial.cumulativeTokens, 100)

        let handle = try FileHandle(forWritingTo: transcript)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(tokenCountLine(total: 175).utf8))
        try handle.close()

        let appended = try CodexTranscriptTokenScanner.scan(
            codexHome: codexHome.path,
            previousStates: initial.fileStates
        )
        XCTAssertEqual(appended.cumulativeTokens, 175)
    }

    @MainActor
    func testAccountMonitorUsesTranscriptTokensWhenAppServerIsUnavailable() async throws {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-overlay-codex-monitor-\(UUID().uuidString)", isDirectory: true)
        let archive = codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
        let transcript = archive.appendingPathComponent("rollout.jsonl")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: codexHome) }
        try Data(tokenCountLine(total: 321).utf8).write(to: transcript)

        let suiteName = "CodexAccountUsageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = CodexAccountProfileStore(
            defaults: defaults,
            userHome: "/Users/tester",
            createsDefaultProfile: false
        )
        let profile = try store.addProfile(displayName: "Local", codexHome: codexHome.path)
        let monitor = CodexAccountMonitor(profileStore: store, binaryPathProvider: { "/missing/codex" })

        await monitor.refresh(profile.id)

        XCTAssertEqual(monitor.snapshot(for: profile.id)?.tokenActivity.lifetimeTokens, 321)
        XCTAssertNil(monitor.errors[profile.id])
    }

    @MainActor
    func testProviderIsUnavailableWhenNoCodexProfileIsSelected() async {
        let service = CodexProviderService(codexHomeProvider: { nil })
        let isDetected = await service.detect()

        XCTAssertFalse(isDetected)
        XCTAssertFalse(service.isDetected)
        XCTAssertFalse(service.isAuthenticated)
    }

    func testRefreshBatchesCoverZeroOneTwoFiveAndTwentyProfilesWithBoundedConcurrency() {
        for count in [0, 1, 2, 5, 20] {
            let profiles = (0..<count).map { index in
                CodexAccountProfile(
                    displayName: "Account \(index)",
                    codexHome: "/tmp/codex-account-\(index)"
                )
            }
            let batches = CodexAccountMonitor.refreshBatches(
                profiles: profiles,
                maximumConcurrent: 3
            )

            XCTAssertEqual(batches.flatMap { $0 }.count, count)
            XCTAssertTrue(batches.allSatisfy { $0.count <= 3 })
        }
    }

    func testParsesRateLimitsAndTokenActivityFromAppServer() throws {
        let profileID = UUID()
        let rateLimits = Data(
            #"{"id":2,"result":{"rateLimits":{"planType":"pro","primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1785294000},"secondary":{"usedPercent":40,"windowDurationMins":10080,"resetsAt":1785800000}}}}"#.utf8
        )
        let tokenUsage = Data(
            #"{"id":3,"result":{"summary":{"lifetimeTokens":1234567,"peakDailyTokens":45678,"longestRunningTurnSec":540,"currentStreakDays":8,"longestStreakDays":14},"dailyUsageBuckets":[{"startDate":"2026-07-28","tokens":12000},{"startDate":"2026-07-29","tokens":34567}]}}"#.utf8
        )

        let snapshot = try CodexAccountUsageReader.parse(
            profileID: profileID,
            rateLimitsResponse: rateLimits,
            tokenUsageResponse: tokenUsage,
            fetchedAt: Date(timeIntervalSince1970: 1_785_000_000)
        )

        XCTAssertEqual(snapshot.profileID, profileID)
        XCTAssertEqual(snapshot.planType, "pro")
        XCTAssertEqual(snapshot.primaryWindow?.remainingPercent, 75)
        XCTAssertEqual(snapshot.secondaryWindow?.remainingPercent, 60)
        XCTAssertEqual(snapshot.headroom, 60)
        XCTAssertEqual(snapshot.tokenActivity.lifetimeTokens, 1_234_567)
        XCTAssertEqual(snapshot.tokenActivity.dailyBuckets.count, 2)
    }

    func testAccountUsageRequestsOmitParamsForParameterlessAppServerMethods() throws {
        let messages = CodexAccountUsageReader.appServerRequestMessages()

        XCTAssertEqual(messages.count, 4)
        XCTAssertNil(messages[1]["params"])
        XCTAssertNil(messages[2]["params"])
        XCTAssertNil(messages[3]["params"])
        XCTAssertEqual(messages[2]["method"] as? String, "account/rateLimits/read")
        XCTAssertEqual(messages[3]["method"] as? String, "account/usage/read")
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: messages))
    }

    func testResetCreditRequestsOmitParamsForParameterlessAppServerMethods() {
        let messages = CodexAppServerService.resetCreditRequestMessages()

        XCTAssertEqual(messages.count, 3)
        XCTAssertNil(messages[1]["params"])
        XCTAssertNil(messages[2]["params"])
        XCTAssertEqual(messages[2]["method"] as? String, "account/rateLimits/read")
    }

    func testTokenActivitySumsAnArbitrarySevenDayWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_785_283_200) // 2026-07-29 UTC
        let activity = CodexTokenActivity(
            lifetimeTokens: nil,
            peakDailyTokens: nil,
            longestRunningTurnSeconds: nil,
            currentStreakDays: nil,
            longestStreakDays: nil,
            dailyBuckets: [
                CodexDailyTokenUsage(startDate: "2026-07-22", tokens: 1),
                CodexDailyTokenUsage(startDate: "2026-07-23", tokens: 2),
                CodexDailyTokenUsage(startDate: "2026-07-29", tokens: 3),
            ]
        )

        XCTAssertEqual(activity.tokens(inLastDays: 7, now: now, calendar: calendar), 5)
    }

    private func tokenCountLine(total: Int) -> String {
        #"{"payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":\#(total)}}}}"# + "\n"
    }
}
