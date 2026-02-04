import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let usageService: UsageDataService
    var panelConfigStore: PanelConfigStore?

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            if let store = panelConfigStore {
                PanelSettingsTab(configStore: store)
                    .tabItem { Label("Panels", systemImage: "square.on.square") }
            }
        }
        .frame(width: 500, height: 620)
    }

    // MARK: - General Tab

    @ViewBuilder
    private var generalTab: some View {
        Form {
            Section("Display") {
                Toggle("Show floating overlay", isOn: $settings.showOverlay)

                Picker("Menu bar indicator", selection: $settings.menuBarIndicatorStyle) {
                    ForEach(MenuBarIndicatorStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }

                Toggle("Global hotkey (\u{2318}\u{21E7}A)", isOn: $settings.globalHotkeyEnabled)
            }

            Section("Alerts") {
                Toggle("Cost threshold alerts (70%, 90%)", isOn: $settings.costAlertEnabled)
            }

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
        .formStyle(.grouped)
    }

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
