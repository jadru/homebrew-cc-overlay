import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let multiService: MultiProviderUsageService

    var body: some View {
        Form {
            providersSection
            overlaySection
            displaySection
            alertsSection
            rateLimitsSection
            dataSection
            startupSection
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
            Toggle("Cost threshold alerts (70%, 90%)", isOn: $settings.costAlertEnabled)
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
                            Text(provider == .claudeCode ? "Anthropic API (live)" : "OpenAI (live)")
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
                    LabeledContent("Source") {
                        Text("No data").foregroundStyle(.secondary)
                    }
                }

                if multiService.activeProviders.count > 1 && provider != multiService.activeProviders.last {
                    Divider()
                }
            }

            if multiService.activeProviders.isEmpty {
                Text("No providers detected")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data Section

    @ViewBuilder
    private var dataSection: some View {
        Section("Data") {
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

    // MARK: - Helpers

    @ViewBuilder
    private func rateBucketRow(_ bucket: RateBucket) -> some View {
        LabeledContent(bucket.label) {
            HStack(spacing: 6) {
                Text("\(Int(min(bucket.utilization, 100)))% used")
                    .foregroundStyle(
                        bucket.utilization >= 90 ? .red :
                        bucket.utilization >= 70 ? .orange : .secondary
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
                        limit.utilizationPercentage >= 90 ? .red :
                        limit.utilizationPercentage >= 70 ? .orange : .secondary
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
