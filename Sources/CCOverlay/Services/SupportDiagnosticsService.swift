import AppKit
import Foundation

@MainActor
enum SupportDiagnosticsService {
    static let issuesURL = URL(string: "https://github.com/\(AppConstants.githubRepo)/issues/new?template=bug_report.yml")!
    static let feedbackURL = URL(string: "https://github.com/\(AppConstants.githubRepo)/issues/new?template=user_feedback.yml")!

    static func report(
        settings: AppSettings,
        multiService: MultiProviderUsageService
    ) -> String {
        let formatter = ISO8601DateFormatter()
        let activationText = settings.activationDuration.map {
            DurationFormatting.compactReset($0)
        } ?? "not recorded"
        let feedback = multiService.decisionFeedbackSummary

        var lines = [
            "## CC-Overlay diagnostics",
            "- App: \(UpdateService.currentAppVersion)",
            "- macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "- Architecture: \(ProcessInfo.processInfo.machineArchitecture)",
            "- Refresh interval: \(Int(settings.refreshInterval)) seconds",
            "- Claude OAuth opt-in: \(settings.claudeOAuthEnabled ? "enabled" : "disabled")",
            "- Time to first usable data: \(activationText)",
            "- Recommendation: \(multiService.usageDecision.title)",
            "- Preferred terminal: \(settings.preferredTerminal.label)",
            "- Full Reset policy: \(settings.fullResetPolicy.label)",
            "- Recommendation feedback: \(feedback.helpful) helpful / \(feedback.unhelpful) not helpful",
            "",
            "### Providers",
        ]

        for provider in CLIProvider.allCases {
            let data = multiService.usageData(for: provider)
            let health = multiService.providerHealth(for: provider)
            let refresh = data.lastRefresh.map { formatter.string(from: $0) } ?? "never"
            lines.append(
                "- \(provider.rawValue): state=\(health.activation.kind.rawValue), available=\(data.isAvailable), estimated=\(data.isEstimated), refreshed=\(refresh), failures=\(health.consecutiveFailures)"
            )
            if data.error != nil {
                lines.append("  - Error present: yes (details intentionally excluded)")
            }
        }

        lines.append("")
        lines.append("Credentials, usage history, project names, and local file paths are intentionally excluded.")
        return lines.joined(separator: "\n")
    }

    static func copyReport(
        settings: AppSettings,
        multiService: MultiProviderUsageService
    ) {
        UsageExportService.copyToClipboard(
            report(settings: settings, multiService: multiService)
        )
    }
}

private extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
