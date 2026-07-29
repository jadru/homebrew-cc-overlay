import XCTest
@testable import CCOverlay

final class UpdateServiceTests: XCTestCase {
    func testLatestReleaseVersionParsesFromGitHubRedirectURL() {
        let url = URL(string: "https://github.com/jadru/homebrew-cc-overlay/releases/tag/v0.10.4")
        XCTAssertEqual(UpdateService.versionFromReleaseURL(url), "0.10.4")
    }

    func testScheduledCheckFailureRemainsSilent() {
        XCTAssertEqual(UpdateService.checkFailureState(presentsErrors: false), .idle)
    }

    func testManualCheckFailureRemainsVisible() {
        guard case .error(let message) = UpdateService.checkFailureState(presentsErrors: true) else {
            return XCTFail("Manual update check should expose an error")
        }
        XCTAssertTrue(message.contains("GitHub"))
    }

    func testCurrentVersionPrefersInstalledBundleMetadata() {
        XCTAssertEqual(
            UpdateService.resolvedCurrentVersion(
                bundleVersion: "0.10.1",
                fallbackVersion: "0.10.0"
            ),
            "0.10.1"
        )
    }

    func testCurrentVersionFallsBackWhenBundleMetadataIsMissing() {
        XCTAssertEqual(
            UpdateService.resolvedCurrentVersion(
                bundleVersion: nil,
                fallbackVersion: "0.10.3"
            ),
            "0.10.3"
        )
    }

    func testSuccessfulBrewExitDoesNotCountWithoutTargetVersionInstalled() {
        XCTAssertFalse(
            UpdateService.installedVersionSatisfiesTarget(
                processSucceeded: true,
                installedVersion: "0.10.1",
                targetVersion: "0.10.2"
            )
        )
    }

    func testInstalledTargetVersionCountsAsSuccessfulUpdate() {
        XCTAssertTrue(
            UpdateService.installedVersionSatisfiesTarget(
                processSucceeded: true,
                installedVersion: "0.10.2",
                targetVersion: "0.10.2"
            )
        )
    }

    func testNewerInstalledVersionAlsoSatisfiesTarget() {
        XCTAssertTrue(
            UpdateService.installedVersionSatisfiesTarget(
                processSucceeded: true,
                installedVersion: "0.10.4",
                targetVersion: "0.10.3"
            )
        )
    }

    func testFailedBrewProcessNeverCountsAsSuccessfulUpdate() {
        XCTAssertFalse(
            UpdateService.installedVersionSatisfiesTarget(
                processSucceeded: false,
                installedVersion: "0.10.3",
                targetVersion: "0.10.3"
            )
        )
    }

    func testHomebrewCandidatesCoverAppleSiliconAndIntelDefaults() {
        let candidates = UpdateService.homebrewCandidatePaths(home: "/Users/tester")

        XCTAssertTrue(candidates.contains("/opt/homebrew/bin/brew"))
        XCTAssertTrue(candidates.contains("/usr/local/bin/brew"))
    }

    func testHomebrewResolutionDoesNotDependOnShellPATH() {
        let candidates = UpdateService.homebrewCandidatePaths(home: "/Users/tester")
        let resolved = UpdateService.firstExecutablePath(in: candidates) { path in
            path == "/opt/homebrew/bin/brew"
        }

        XCTAssertEqual(resolved, "/opt/homebrew/bin/brew")
    }

    func testHomebrewResolutionReturnsNilWhenNoCandidateIsExecutable() {
        let resolved = UpdateService.firstExecutablePath(
            in: UpdateService.homebrewCandidatePaths(home: "/Users/tester"),
            isExecutable: { _ in false }
        )

        XCTAssertNil(resolved)
    }
}
