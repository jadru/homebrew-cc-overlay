import XCTest
@testable import CCOverlay

final class UpdateServiceTests: XCTestCase {
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
}
