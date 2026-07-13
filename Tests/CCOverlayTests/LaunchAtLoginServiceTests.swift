import XCTest
@testable import CCOverlay

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
    func testDisabledPreferenceDoesNotRegisterLoginItem() throws {
        let registration = MockLoginItemRegistration(status: .enabled)
        let service = LaunchAtLoginService(registration: registration)

        let repaired = try service.repairIfNeeded(
            isEnabled: false,
            registeredVersion: "0.10.5",
            currentVersion: "0.10.6"
        )

        XCTAssertFalse(repaired)
        XCTAssertEqual(registration.calls, [])
    }

    func testMatchingVersionDoesNotReregisterLoginItem() throws {
        let registration = MockLoginItemRegistration(status: .enabled)
        let service = LaunchAtLoginService(registration: registration)

        let repaired = try service.repairIfNeeded(
            isEnabled: true,
            registeredVersion: "0.10.6",
            currentVersion: "0.10.6"
        )

        XCTAssertFalse(repaired)
        XCTAssertEqual(registration.calls, [])
    }

    func testUpgradeReplacesEnabledRegistrationWithCurrentApp() throws {
        let registration = MockLoginItemRegistration(status: .enabled)
        let service = LaunchAtLoginService(registration: registration)

        let repaired = try service.repairIfNeeded(
            isEnabled: true,
            registeredVersion: "0.10.5",
            currentVersion: "0.10.6"
        )

        XCTAssertTrue(repaired)
        XCTAssertEqual(registration.calls, [.unregister, .register])
    }

    func testMissingRegistrationIsRegisteredWithoutUnregistering() throws {
        let registration = MockLoginItemRegistration(status: .notRegistered)
        let service = LaunchAtLoginService(registration: registration)

        let repaired = try service.repairIfNeeded(
            isEnabled: true,
            registeredVersion: nil,
            currentVersion: "0.10.6"
        )

        XCTAssertTrue(repaired)
        XCTAssertEqual(registration.calls, [.register])
    }
}

@MainActor
private enum LoginItemRegistrationCall: Equatable {
    case register
    case unregister
}

@MainActor
private final class MockLoginItemRegistration: LoginItemRegistering {
    var status: LoginItemRegistrationStatus
    var calls: [LoginItemRegistrationCall] = []

    init(status: LoginItemRegistrationStatus) {
        self.status = status
    }

    func register() throws {
        calls.append(.register)
        status = .enabled
    }

    func unregister() throws {
        calls.append(.unregister)
        status = .notRegistered
    }
}
