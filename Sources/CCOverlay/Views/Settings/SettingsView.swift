import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let usageService: UsageDataService

    var body: some View {
        Form {
            overlaySection
            displaySection
            alertsSection
            rateLimitsSection
            dataSection
            startupSection
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 620)
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
            if usageService.hasAPIData {
                let usage = usageService.oauthUsage

                LabeledContent("Source") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Anthropic API (live)")
                            .foregroundStyle(.secondary)
                    }
                }

                if let plan = usageService.detectedPlan {
                    LabeledContent("Plan") {
                        Text(formatPlanName(plan))
                            .foregroundStyle(.secondary)
                    }
                }

                bucketRow("5-Hour Window", usage.fiveHour)
                bucketRow("Weekly (All Models)", usage.sevenDay)

                if let sonnet = usage.sevenDaySonnet {
                    bucketRow("Weekly (Sonnet)", sonnet)
                }

                LabeledContent("Extra Usage") {
                    Text(usage.extraUsageEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("Source") {
                    Text("Local JSONL (estimated)")
                        .foregroundStyle(.secondary)
                }

                Picker("Plan tier", selection: $settings.planTier) {
                    ForEach(PlanTier.allCases) { tier in
                        Text(tier.rawValue).tag(tier)
                    }
                }

                if settings.planTier == .custom {
                    TextField(
                        "Weighted cost limit (5hr)",
                        value: $settings.customWeightedLimit,
                        format: .number
                    )
                }

                LabeledContent("Current limit") {
                    Text(NumberFormatting.formatWeightedCost(settings.weightedCostLimit))
                        .foregroundStyle(.secondary)
                }
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
                usageService.updateRefreshInterval(newValue)
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
    private func bucketRow(_ label: String, _ bucket: UsageBucket) -> some View {
        LabeledContent(label) {
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

    private func formatPlanName(_ type: String) -> String {
        switch type {
        case "max_5": return "Max ($100/mo)"
        case "max_20": return "Max ($200/mo)"
        case "pro": return "Pro ($20/mo)"
        default: return type
        }
    }
}
