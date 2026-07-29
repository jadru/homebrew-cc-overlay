import Foundation

enum ActivationDoctor {
    static func assess(
        provider: CLIProvider,
        data: ProviderUsageData,
        isActive: Bool,
        isChecking: Bool,
        isStale: Bool,
        binaryPath: String?
    ) -> ProviderActivationStatus {
        if isChecking && !data.isAvailable {
            return ProviderActivationStatus(
                provider: provider,
                kind: .checking,
                title: "Checking",
                detail: "Looking for the CLI, sign-in, and current usage.",
                recoveryCommand: nil
            )
        }

        guard binaryPath != nil else {
            return ProviderActivationStatus(
                provider: provider,
                kind: .cliMissing,
                title: "CLI not installed",
                detail: "Install \(provider.rawValue), then return here to recheck.",
                recoveryCommand: provider.installCommand
            )
        }

        if let error = data.error {
            let normalized = error.lowercased()
            if normalized.contains("invalid")
                || normalized.contains("did not include")
                || normalized.contains("response changed") {
                return ProviderActivationStatus(
                    provider: provider,
                    kind: .schemaChanged,
                    title: "Provider response changed",
                    detail: "CC-Overlay could not recognize the latest usage response. Update the app or report this diagnostic.",
                    recoveryCommand: nil
                )
            }
            if normalized.contains("auth")
                || normalized.contains("sign in")
                || normalized.contains("expired")
                || normalized.contains("unauthorized") {
                return ProviderActivationStatus(
                    provider: provider,
                    kind: .signInRequired,
                    title: "Sign-in required",
                    detail: error,
                    recoveryCommand: provider.loginCommand
                )
            }
            return ProviderActivationStatus(
                provider: provider,
                kind: .failed,
                title: "Usage check failed",
                detail: error,
                recoveryCommand: provider.loginCommand
            )
        }

        if data.isAvailable && isStale {
            return ProviderActivationStatus(
                provider: provider,
                kind: .stale,
                title: "Data is stale",
                detail: "The last successful usage snapshot is older than expected.",
                recoveryCommand: nil
            )
        }

        if data.isAvailable {
            return ProviderActivationStatus(
                provider: provider,
                kind: .ready,
                title: "Live usage ready",
                detail: data.planName ?? "Connected and refreshing normally.",
                recoveryCommand: nil
            )
        }

        return ProviderActivationStatus(
            provider: provider,
            kind: .signInRequired,
            title: isActive ? "Waiting for usage" : "Sign-in required",
            detail: "Start \(provider.rawValue) once and complete its sign-in flow.",
            recoveryCommand: provider.loginCommand
        )
    }
}
