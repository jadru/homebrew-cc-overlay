import ServiceManagement

enum LoginItemRegistrationStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

@MainActor
protocol LoginItemRegistering: AnyObject {
    var status: LoginItemRegistrationStatus { get }
    func register() throws
    func unregister() throws
}

@MainActor
final class SystemLoginItemRegistration: LoginItemRegistering {
    var status: LoginItemRegistrationStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
final class LaunchAtLoginService {
    private let registration: any LoginItemRegistering

    init(registration: any LoginItemRegistering = SystemLoginItemRegistration()) {
        self.registration = registration
    }

    @discardableResult
    func repairIfNeeded(
        isEnabled: Bool,
        registeredVersion: String?,
        currentVersion: String
    ) throws -> Bool {
        guard isEnabled, registeredVersion != currentVersion else { return false }

        switch registration.status {
        case .enabled, .requiresApproval:
            try registration.unregister()
        case .notRegistered, .notFound:
            break
        }

        try registration.register()
        return true
    }
}
