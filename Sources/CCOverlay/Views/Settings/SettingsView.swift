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
                        Text(isActive ? "Active" : "Not detected")
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

            Toggle("Enable Claude Code", isOn: $settings.claudeCodeEnabled)
            Toggle("Enable Codex", isOn: $settings.codexEnabled)
            Toggle("Enable Gemini", isOn: $settings.geminiEnabled)

            LabeledContent("Codex API Key") {
                SecureField("sk-...", text: Binding(
                    get: { settings.codexAPIKey ?? "" },
                    set: { settings.codexAPIKey = $0.isEmpty ? nil : $0 }
                ))
                .frame(width: 200)
                .textFieldStyle(.roundedBorder)
            }

            Text("API key is read from: OPENAI_API_KEY env > ~/.codex/config.toml > manual entry above")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // Codex auth status indicator
            codexAuthStatusRow

            LabeledContent("Gemini API Key") {
                SecureField("AIza...", text: Binding(
                    get: { settings.geminiAPIKey ?? "" },
                    set: { settings.geminiAPIKey = $0.isEmpty ? nil : $0 }
                ))
                .frame(width: 200)
                .textFieldStyle(.roundedBorder)
            }

            Text("API key is read from: GEMINI_API_KEY env > ~/.gemini/.env > manual entry above")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // Gemini auth status indicator
            geminiAuthStatusRow
        }
    }

    @ViewBuilder
    private var codexAuthStatusRow: some View {
        let codexData = multiService.usageData(for: .codex)
        if settings.codexEnabled {
            if let errorMsg = codexData.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text(errorMsg)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            } else if codexData.isAvailable, let plan = codexData.planName {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 10))
                    Text("ChatGPT OAuth connected (plan: \(plan))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if !multiService.activeProviders.contains(.codex) {
                HStack(spacing: 4) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                    Text("~/.codex/auth.json not found — install Codex CLI first")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var geminiAuthStatusRow: some View {
        let geminiData = multiService.usageData(for: .gemini)
        if settings.geminiEnabled {
            if let errorMsg = geminiData.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text(errorMsg)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            } else if geminiData.isAvailable, let plan = geminiData.planName {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 10))
                    Text("Google OAuth connected (\(plan))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if !multiService.activeProviders.contains(.gemini) {
                HStack(spacing: 4) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                    Text("~/.gemini not found — install Gemini CLI first")
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
            Toggle("Show floating overlay", isOn: $settings.showOverlay)

            Toggle("Always expanded", isOn: $settings.pillAlwaysExpanded)
                .disabled(!settings.showOverlay)

            Toggle("Show daily cost", isOn: $settings.pillShowDailyCost)
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

            Toggle("Click-through mode", isOn: $settings.pillClickThrough)
                .disabled(!settings.showOverlay)
        }
    }

    // MARK: - Display Section

    @ViewBuilder
    private var displaySection: some View {
        Section("Display") {
            Picker("Menu bar indicator", selection: $settings.menuBarIndicatorStyle) {
                ForEach(MenuBarIndicatorStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }

            Toggle("Global hotkey (\u{2318}\u{21E7}A)", isOn: $settings.globalHotkeyEnabled)
        }
    }

    // MARK: - Alerts Section

    @ViewBuilder
    private var alertsSection: some View {
        Section("Alerts") {
            Toggle("Cost threshold alerts", isOn: $settings.costAlertEnabled)

            if settings.costAlertEnabled {
                LabeledContent("Warning threshold") {
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

                LabeledContent("Critical threshold") {
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
                            Text(provider == .claudeCode ? "Anthropic API (live)" :
                                 provider == .codex ? "OpenAI (live)" :
                                 "Google AI (estimated)")
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
                if !multiService.activeProviders.contains(provider) && isProviderEnabled(provider) {
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

            if CLIProvider.allCases.allSatisfy({ !isProviderEnabled($0) }) {
                Text("All providers are disabled — enable one in Providers above")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Data Section

    @ViewBuilder
    private var dataSection: some View {
        Section("Data") {
            Picker("Claude plan tier", selection: $settings.planTier) {
                ForEach(PlanTier.allCases) { tier in
                    Text(tier.rawValue).tag(tier)
                }
            }

            if settings.planTier == .custom {
                LabeledContent("Custom weighted limit") {
                    TextField(
                        "5,000,000",
                        value: $settings.customWeightedLimit,
                        formatter: weightedLimitFormatter
                    )
                    .frame(width: 140)
                    .textFieldStyle(.roundedBorder)
                }
            }

            Picker("Refresh interval", selection: $settings.refreshInterval) {
                Text("15 seconds").tag(15.0 as TimeInterval)
                Text("30 seconds").tag(30.0 as TimeInterval)
                Text("1 minute").tag(60.0 as TimeInterval)
                Text("5 minutes").tag(300.0 as TimeInterval)
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
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
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
            Toggle("Automatic updates", isOn: $settings.autoUpdateEnabled)

            LabeledContent("Current version") {
                Text(AppConstants.version)
                    .foregroundStyle(.secondary)
            }

            if let lastCheck = settings.lastUpdateCheck {
                LabeledContent("Last checked") {
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
                Text("Up to date")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        case .updateAvailable(let version):
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 10))
                Text("v\(version) available")
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

    private func isProviderEnabled(_ provider: CLIProvider) -> Bool {
        switch provider {
        case .claudeCode: return settings.claudeCodeEnabled
        case .codex: return settings.codexEnabled
        case .gemini: return settings.geminiEnabled
        }
    }

    @ViewBuilder
    private func providerSetupHint(for provider: CLIProvider) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .foregroundStyle(.tertiary)
                .font(.system(size: 10))
            Text(setupHintText(for: provider))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func setupHintText(for provider: CLIProvider) -> String {
        switch provider {
        case .claudeCode:
            return "Install Claude Code and sign in to see rate limits"
        case .codex:
            return "Install Codex CLI and run 'codex --login' to see rate limits"
        case .gemini:
            return "Install Gemini CLI and run 'gemini' to authenticate"
        }
    }

    @ViewBuilder
    private func rateBucketRow(_ bucket: RateBucket) -> some View {
        LabeledContent(bucket.label) {
            HStack(spacing: 6) {
                Text("\(Int(min(bucket.utilization, 100)))% used")
                    .foregroundStyle(
                        bucket.utilization >= settings.alertCriticalThreshold ? .red :
                        bucket.utilization >= settings.alertWarningThreshold ? .orange : .secondary
                    )
                if let resetsAt = bucket.resetsAt {
                    Text("resets \(resetsAt, style: .relative)")
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

        spendingLimitRow("Individual Cap", quota.individualLimit)

        if quota.seatTierLimit.capDollars > 0 {
            spendingLimitRow("Tier Cap", quota.seatTierLimit)
        }

        if quota.organizationLimit.capDollars > 0 {
            spendingLimitRow("Org Cap", quota.organizationLimit)
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
                    Text("resets \(resetsAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
