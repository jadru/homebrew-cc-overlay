import XCTest
@testable import CCOverlay

final class ActivationDoctorTests: XCTestCase {
    func testMissingCLIProvidesInstallRecovery() {
        let status = ActivationDoctor.assess(
            provider: .codex,
            data: .empty(for: .codex),
            isActive: false,
            isChecking: false,
            isStale: false,
            binaryPath: nil
        )

        XCTAssertEqual(status.kind, .cliMissing)
        XCTAssertEqual(status.recoveryCommand, "npm i -g @openai/codex")
    }

    func testInstalledProviderWithoutUsageRequestsSignIn() {
        let status = ActivationDoctor.assess(
            provider: .codex,
            data: .empty(for: .codex),
            isActive: false,
            isChecking: false,
            isStale: false,
            binaryPath: "/usr/local/bin/codex"
        )

        XCTAssertEqual(status.kind, .signInRequired)
        XCTAssertEqual(status.recoveryCommand, "codex --login")
    }

    func testMalformedProviderResponseIsReportedAsSchemaChange() {
        let status = ActivationDoctor.assess(
            provider: .codex,
            data: .empty(
                for: .codex,
                error: "Codex usage response did not include a primary rate limit"
            ),
            isActive: true,
            isChecking: false,
            isStale: false,
            binaryPath: "/usr/local/bin/codex"
        )

        XCTAssertEqual(status.kind, .schemaChanged)
        XCTAssertNil(status.recoveryCommand)
    }

    func testLiveProviderIsReady() {
        let status = ActivationDoctor.assess(
            provider: .claudeCode,
            data: ProviderUsageData(
                provider: .claudeCode,
                isAvailable: true,
                usedPercentage: 20,
                remainingPercentage: 80,
                primaryWindowLabel: "5h"
            ),
            isActive: true,
            isChecking: false,
            isStale: false,
            binaryPath: "/opt/homebrew/bin/claude"
        )

        XCTAssertEqual(status.kind, .ready)
    }
}

