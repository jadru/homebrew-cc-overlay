import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let multiService: MultiProviderUsageService
    let updateService: UpdateService
    @State private var codexKeyDisclosureExpanded = false
    @State private var geminiKeyDisclosureExpanded = false
    @State private var advancedDisclosureExpanded = false
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
            appSection
            advancedSection
        }
        .formStyle(.grouped)
        .frame(width: DesignTokens.Layout.settingsWidth, height: DesignTokens.Layout.settingsHeight)
    }

    // MARK: - Providers Section

    @ViewBuilder
    private var providersSection: some View {
        Section {
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

            // Codex auth status indicator
            providerAuthStatusRow(
                for: .codex,
                data: multiService.usageData(for: .codex),
                connectedMessage: { plan in
                    if let plan {
                        return "ChatGPT OAuth connected (plan: \(plan))"
                    }
                    return "ChatGPT OAuth connected"
                },
                notFoundText: "~/.codex/auth.json not found — install Codex CLI first"
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
                notFoundText: "~/.gemini not found — install Gemini CLI first"
            )

            DisclosureGroup(
                isExpanded: Binding(
                    get: { codexKeyDisclosureExpanded || geminiKeyDisclosureExpanded },
                    set: { newValue in
                        codexKeyDisclosureExpanded = newValue
                        geminiKeyDisclosureExpanded = newValue
                    }
                ),
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Codex manual key") {
                            SecureField("sk-...", text: Binding(
                                get: { settings.codexAPIKey ?? "" },
                                set: { settings.codexAPIKey = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(width: 200)
                            .textFieldStyle(.roundedBorder)
                        }

                        LabeledContent("Gemini manual key") {
                            SecureField("AIza...", text: Binding(
                                get: { settings.geminiAPIKey ?? "" },
                                set: { settings.geminiAPIKey = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(width: 200)
                            .textFieldStyle(.roundedBorder)
                        }

                        Text("OAuth is the default. Manual API keys are only needed for fallback or non-OAuth setups.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                },
                label: {
                    Label("Advanced credentials", systemImage: "key.horizontal")
                }
            )
        } header: {
            sectionHeader("Providers", systemImage: "square.grid.2x2")
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
        Section {
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
        } header: {
            sectionHeader("Overlay", systemImage: "capsule.portrait")
        }
    }

    // MARK: - Display Section

    @ViewBuilder
    private var displaySection: some View {
        Section {
            Picker("Menu bar indicator", selection: $settings.menuBarIndicatorStyle) {
                ForEach(MenuBarIndicatorStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }

            Toggle("Global hotkey (\u{2318}\u{21E7}A)", isOn: $settings.globalHotkeyEnabled)
        } header: {
            sectionHeader("Display", systemImage: "menubar.rectangle")
        }
    }

    // MARK: - Alerts Section

    @ViewBuilder
    private var alertsSection: some View {
        Section {
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
        } header: {
            sectionHeader("Alerts", systemImage: "bell.badge")
        }
    }

    // MARK: - App Section

    @ViewBuilder
    private var appSection: some View {
        Section {
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
        } header: {
            sectionHeader("App", systemImage: "switch.2")
        }
    }

    // MARK: - Advanced Section

    @ViewBuilder
    private var advancedSection: some View {
        Section {
            DisclosureGroup(
                isExpanded: $advancedDisclosureExpanded,
                content: {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Refresh interval", selection: $settings.refreshInterval) {
                            Text("15 seconds").tag(15.0 as TimeInterval)
                            Text("30 seconds").tag(30.0 as TimeInterval)
                            Text("1 minute").tag(60.0 as TimeInterval)
                            Text("5 minutes").tag(300.0 as TimeInterval)
                        }
                        .onChange(of: settings.refreshInterval) { _, newValue in
                            multiService.updateRefreshInterval(newValue)
                        }

                        Picker("Claude fallback plan", selection: $settings.planTier) {
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

                        Toggle("UI flow logging", isOn: $settings.debugFlowLogging)

                        Text("Only change these if OAuth detection or Claude fallback estimation needs tuning.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                },
                label: {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
            )
        } header: {
            sectionHeader("Advanced", systemImage: "slider.horizontal.3")
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

    @ViewBuilder
    private func providerSetupHint(for provider: CLIProvider) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .foregroundStyle(.tertiary)
                .font(.system(size: 10))
            Text(provider.setupHint)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
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

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
    }
}
