import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let multiService: MultiProviderUsageService
    let updateService: UpdateService
    private let weightedLimitFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter
    }()

    var body: some View {
        Form {
            providersSection
            overlaySection
            displaySection
            alertsSection
            developerSection
            rateLimitsSection
            dataSection
            startupSection
            updatesSection
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 700)
    }

    // MARK: - Providers Section

    @ViewBuilder
    private var providersSection: some View {
        Section("Providers") {
            ForEach(CLIProvider.allCases) { provider in
                let isActive = multiService.activeProviders.contains(provider)

                LabeledContent {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isActive ? .green : .red)
                            .frame(width: 6, height: 6)
                        Text(isActive ? "Active" : "Not Detected")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 12))
                        Text(provider.rawValue)
                    }
                }
            }

            Toggle("Claude Code", isOn: $settings.claudeCodeEnabled)
            Toggle("Codex", isOn: $settings.codexEnabled)
            Toggle("Gemini", isOn: $settings.geminiEnabled)

            // Codex auth status indicator
            providerAuthStatusRow(
                for: .codex,
                data: multiService.usageData(for: .codex),
                connectedMessage: { plan in
                    if let plan {
                        return "ChatGPT OAuth connected (Plan: \(plan))"
                    }
                    return "ChatGPT OAuth connected"
                },
                notFoundText: "~/.codex/auth.json not found. Please install Codex CLI first"
            )

            // Gemini auth status indicator
            providerAuthStatusRow(
                for: .gemini,
                data: multiService.usageData(for: .gemini),
                connectedMessage: { plan in
                    if let plan {
                        return "Google OAuth connected (\(plan))"
                    }
                    return "Google OAuth connected"
                },
                notFoundText: "~/.gemini folder not found. Please install Gemini CLI first"
            )
        }
    }

    @ViewBuilder
    private func providerAuthStatusRow(
        for provider: CLIProvider,
        data: ProviderUsageData,
        connectedMessage: (String?) -> String,
        notFoundText: String
    ) -> some View {
        if (provider == .codex ? settings.codexEnabled : settings.geminiEnabled) {
            if let errorMsg = data.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text(errorMsg)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            } else if data.isAvailable {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 10))
                    Text(connectedMessage(data.planName))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if !multiService.activeProviders.contains(provider) {
                HStack(spacing: 4) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                    Text(notFoundText)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Overlay Section

    @ViewBuilder
    private var overlaySection: some View {
        Section("Overlay") {
            Toggle("Show Floating Overlay", isOn: $settings.showOverlay)

            Toggle("Always Expanded", isOn: $settings.pillAlwaysExpanded)
                .disabled(!settings.showOverlay)

            Toggle("Show Daily Cost", isOn: $settings.pillShowDailyCost)
                .disabled(!settings.showOverlay)

            LabeledContent("Opacity") {
                HStack(spacing: 8) {
                    Slider(value: $settings.pillOpacity, in: 0.5...1.0, step: 0.1)
                        .frame(width: 120)
                    Text("\(Int(settings.pillOpacity * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
            .disabled(!settings.showOverlay)

            Toggle("Click-Through Mode", isOn: $settings.pillClickThrough)
                .disabled(!settings.showOverlay)
        }
    }

    // MARK: - Display Section

    @ViewBuilder
    private var displaySection: some View {
        Section("Display") {
            Picker("Menu Bar Style", selection: $settings.menuBarIndicatorStyle) {
                ForEach(MenuBarIndicatorStyle.allCases) { style in
                    Text(localizedMenuBarStyle(style)).tag(style)
                }
            }

            Toggle("Global Hotkey (\u{2318}\u{21E7}A)", isOn: $settings.globalHotkeyEnabled)
        }
    }

    // MARK: - Alerts Section

    @ViewBuilder
    private var alertsSection: some View {
        Section("Alerts") {
            Toggle("Cost Threshold Alerts", isOn: $settings.costAlertEnabled)

            if settings.costAlertEnabled {
                LabeledContent("Warning Threshold") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.alertWarningThreshold, in: 10...95, step: 1)
                            .frame(width: 140)
                            .onChange(of: settings.alertWarningThreshold) { _, newValue in
                                if newValue >= settings.alertCriticalThreshold {
                                    settings.alertCriticalThreshold = min(newValue + 1, 100)
                                }
                            }
                        Text("\(Int(settings.alertWarningThreshold))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                LabeledContent("Critical Threshold") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.alertCriticalThreshold, in: 20...100, step: 1)
                            .frame(width: 140)
                            .onChange(of: settings.alertCriticalThreshold) { _, newValue in
                                if newValue <= settings.alertWarningThreshold {
                                    settings.alertWarningThreshold = max(newValue - 1, 1)
                                }
                            }
                        Text("\(Int(settings.alertCriticalThreshold))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var developerSection: some View {
        Section("Developer") {
            Toggle("UI Flow Logging", isOn: $settings.debugFlowLogging)
            Text("Logs provider detection, rendering, and alert transitions for local GUI verification.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Rate Limits Section

    @ViewBuilder
    private var rateLimitsSection: some View {
        Section("Rate Limits") {
            ForEach(multiService.activeProviders) { provider in
                let data = multiService.usageData(for: provider)

                if multiService.activeProviders.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 10))
                        Text(provider.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                }

                if data.isAvailable {
                    LabeledContent("Source") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(provider == .claudeCode ? "Anthropic API (Live)" :
                                 provider == .codex ? "OpenAI (Live)" :
                                 "Google AI (Estimated)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let plan = data.planName {
                        LabeledContent("Plan") {
                            Text(plan).foregroundStyle(.secondary)
                        }
                    }

                    ForEach(data.rateLimitBuckets) { bucket in
                        rateBucketRow(bucket)
                    }

                    // Claude-specific enterprise quota
                    if let enterprise = data.enterpriseQuota, enterprise.isAvailable {
                        Divider()
                        enterpriseSettingsRows(enterprise)
                    }
                } else {
                    providerSetupHint(for: provider)
                }

                if multiService.activeProviders.count > 1 && provider != multiService.activeProviders.last {
                    Divider()
                }
            }

            // Show hints for providers that are enabled but not active
            ForEach(CLIProvider.allCases) { provider in
                if !multiService.activeProviders.contains(provider) && settings.isEnabled(provider) {
                    if !multiService.activeProviders.isEmpty {
                        Divider()
                    }
                    HStack(spacing: 4) {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 10))
                        Text(provider.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.tertiary)
                    providerSetupHint(for: provider)
                }
            }

            if CLIProvider.allCases.allSatisfy({ !settings.isEnabled($0) }) {
                Text("All providers are disabled. Please enable one in the Providers section above")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Data Section

    @ViewBuilder
    private var dataSection: some View {
        Section("Data") {
            Picker("Claude Plan Tier", selection: $settings.planTier) {
                ForEach(PlanTier.allCases) { tier in
                    Text(localizedPlanTier(tier)).tag(tier)
                }
            }

            if settings.planTier == .custom {
                LabeledContent("Custom Weighted Limit") {
                    TextField(
                        "5,000,000",
                        value: $settings.customWeightedLimit,
                        formatter: weightedLimitFormatter
                    )
                    .frame(width: 140)
                    .textFieldStyle(.roundedBorder)
                }
            }

            Picker("Refresh Interval", selection: $settings.refreshInterval) {
                Text("15s").tag(15.0 as TimeInterval)
                Text("30s").tag(30.0 as TimeInterval)
                Text("1m").tag(60.0 as TimeInterval)
                Text("5m").tag(300.0 as TimeInterval)
            }
            .onChange(of: settings.refreshInterval) { _, newValue in
                multiService.updateRefreshInterval(newValue)
            }
        }
    }

    // MARK: - Startup Section

    @ViewBuilder
    private var startupSection: some View {
        Section("Startup") {
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, enabled in
                    let service = SMAppService.mainApp
                    do {
                        if enabled {
                            try service.register()
                        } else {
                            try service.unregister()
                        }
                    } catch {
                        settings.launchAtLogin = !enabled
                    }
                }
        }
    }

    // MARK: - Updates Section

    @ViewBuilder
    private var updatesSection: some View {
        Section("Updates") {
            Toggle("Auto Update", isOn: $settings.autoUpdateEnabled)

            LabeledContent("Current Version") {
                Text(AppConstants.version)
                    .foregroundStyle(.secondary)
            }

            if let lastCheck = settings.lastUpdateCheck {
                LabeledContent("Last Checked") {
                    Text(lastCheck, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Check for Updates") {
                    Task { await updateService.checkForUpdates() }
                }
                .disabled(updateService.updateState == .checking)

                Spacer()

                updateStatusIndicator
            }
        }
    }

    @ViewBuilder
    private var updateStatusIndicator: some View {
        switch updateService.updateState {
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking...")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        case .upToDate:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 10))
                Text("Up to Date")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        case .updateAvailable(let version):
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 10))
                Text("\(version) Available")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
            }
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 10))
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func providerSetupHint(for provider: CLIProvider) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .foregroundStyle(.tertiary)
                .font(.system(size: 10))
            Text(localizedSetupHint(for: provider))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func rateBucketRow(_ bucket: RateBucket) -> some View {
        LabeledContent(bucket.label) {
            HStack(spacing: 6) {
                Text("\(Int(min(bucket.utilization, 100)))% Used")
                    .foregroundStyle(
                        bucket.utilization >= settings.alertCriticalThreshold ? .red :
                        bucket.utilization >= settings.alertWarningThreshold ? .orange : .secondary
                    )
                if let resetsAt = bucket.resetsAt {
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Enterprise Settings

    @ViewBuilder
    private func enterpriseSettingsRows(_ quota: EnterpriseQuota) -> some View {
        if let orgName = quota.organizationName {
            LabeledContent("Organization") {
                Text(orgName).foregroundStyle(.secondary)
            }
        }

        LabeledContent("Seat Tier") {
            Text(quota.seatTier.displayName).foregroundStyle(.secondary)
        }

        spendingLimitRow("Individual Limit", quota.individualLimit)

        if quota.seatTierLimit.capDollars > 0 {
            spendingLimitRow("Tier Limit", quota.seatTierLimit)
        }

        if quota.organizationLimit.capDollars > 0 {
            spendingLimitRow("Organization Limit", quota.organizationLimit)
        }
    }

    @ViewBuilder
    private func spendingLimitRow(_ label: String, _ limit: SpendingLimit) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                Text("\(NumberFormatting.formatDollarCost(limit.usedDollars)) / \(NumberFormatting.formatDollarCost(limit.capDollars))")
                    .foregroundStyle(
                        limit.utilizationPercentage >= settings.alertCriticalThreshold ? .red :
                        limit.utilizationPercentage >= settings.alertWarningThreshold ? .orange : .secondary
                    )
                if let resetsAt = limit.resetsAt {
                    Text("Resets \(resetsAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func localizedMenuBarStyle(_ style: MenuBarIndicatorStyle) -> String {
        switch style {
        case .pieChart: return "Pie Chart"
        case .barChart: return "Bar Chart"
        case .percentage: return "Percentage"
        }
    }

    private func localizedPlanTier(_ tier: PlanTier) -> String {
        switch tier {
        case .pro: return "Pro ($20/mo)"
        case .max5: return "Max ($100/mo)"
        case .max20: return "Max ($200/mo)"
        case .enterprise: return "Enterprise"
        case .custom: return "Custom"
        }
    }

    private func localizedSetupHint(for provider: CLIProvider) -> String {
        switch provider {
        case .claudeCode:
            return "Install Claude Code and log in to view usage limits"
        case .codex:
            return "Install Codex CLI and run 'codex --login' to view usage limits"
        case .gemini:
            return "Install Gemini CLI and authenticate with 'gemini'"
        }
    }
}
