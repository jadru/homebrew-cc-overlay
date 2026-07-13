import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let multiService: MultiProviderUsageService
    let updateService: UpdateService

    @State private var fallbackExpanded = false
    @State private var launchAtLoginStatus: SMAppService.Status = .notRegistered
    @State private var launchAtLoginError: String?

    private let weightedLimitFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter
    }()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            overlayTab
                .tabItem { Label("Overlay", systemImage: "capsule.portrait") }

            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell.badge") }

            advancedTab
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: DesignTokens.Layout.settingsWidth, height: DesignTokens.Layout.settingsHeight)
    }

    private var generalTab: some View {
        Form {
            Section("Providers") {
                ForEach(CLIProvider.allCases) { provider in
                    providerStatusRow(for: provider)

                    if provider == .claudeCode {
                        Toggle("Read Claude OAuth rate limits", isOn: $settings.claudeOAuthEnabled)
                            .onChange(of: settings.claudeOAuthEnabled) { _, _ in
                                multiService.refresh()
                            }

                        Text("Requests Keychain access only when enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("App") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)

                if launchAtLoginStatus == .requiresApproval {
                    Text("Approve CC-Overlay in Login Items to finish enabling it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshLaunchAtLoginStatus)
    }

    private var overlayTab: some View {
        Form {
            Section("Floating overlay") {
                Toggle("Show overlay", isOn: $settings.showOverlay)
                Toggle("Start expanded", isOn: $settings.pillAlwaysExpanded)
                    .disabled(!settings.showOverlay)
                Toggle("Click through", isOn: $settings.pillClickThrough)
                    .disabled(!settings.showOverlay)
            }

            Section("Shortcut") {
                Toggle("Command-Shift-A", isOn: $settings.globalHotkeyEnabled)
            }
        }
        .formStyle(.grouped)
    }

    private var notificationsTab: some View {
        Form {
            Section("Usage alerts") {
                Toggle("Usage threshold alerts", isOn: $settings.costAlertEnabled)

                if settings.costAlertEnabled {
                    thresholdControl(
                        title: "Warning",
                        value: $settings.alertWarningThreshold,
                        range: 10...95
                    )
                    thresholdControl(
                        title: "Critical",
                        value: $settings.alertCriticalThreshold,
                        range: 20...100
                    )
                }
            }

            Section("Updates") {
                Toggle("Check automatically", isOn: $settings.autoUpdateEnabled)

                LabeledContent("Version") {
                    Text(UpdateService.currentAppVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Check for updates") {
                        Task { await updateService.checkForUpdates() }
                    }
                    .disabled(updateService.updateState == .checking)

                    Spacer()

                    updateStatusIndicator
                }
            }
        }
        .formStyle(.grouped)
    }

    private var advancedTab: some View {
        Form {
            Section("Usage data") {
                DisclosureGroup("Fallback and refresh", isExpanded: $fallbackExpanded) {
                    Picker("Refresh", selection: $settings.refreshInterval) {
                        Text("15 seconds").tag(15.0 as TimeInterval)
                        Text("30 seconds").tag(30.0 as TimeInterval)
                        Text("1 minute").tag(60.0 as TimeInterval)
                        Text("5 minutes").tag(300.0 as TimeInterval)
                    }
                    .onChange(of: settings.refreshInterval) { _, interval in
                        multiService.updateRefreshInterval(interval)
                    }

                    Picker("Claude fallback", selection: $settings.planTier) {
                        ForEach(PlanTier.allCases) { tier in
                            Text(tier.rawValue).tag(tier)
                        }
                    }

                    if settings.planTier == .custom {
                        LabeledContent("Weighted limit") {
                            TextField(
                                "5,000,000",
                                value: $settings.customWeightedLimit,
                                formatter: weightedLimitFormatter
                            )
                            .frame(width: 140)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            Section {
                Toggle("Diagnostic logging", isOn: $settings.debugFlowLogging)
            }
        }
        .formStyle(.grouped)
    }

    private func providerStatusRow(for provider: CLIProvider) -> some View {
        let data = multiService.usageData(for: provider)

        return LabeledContent {
            providerConnectionStatus(data)
        } label: {
            HStack(spacing: 6) {
                ProviderIconView(provider: provider, size: 13)
                Text(provider.rawValue)
            }
        }
    }

    @ViewBuilder
    private func providerConnectionStatus(_ data: ProviderUsageData) -> some View {
        if let error = data.error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.orange)
        } else if data.isAvailable {
            let detail = data.planName.map { "Connected - \($0)" } ?? "Connected"
            Label(detail, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        } else {
            Label("Not detected", systemImage: "minus.circle")
                .foregroundStyle(.tertiary)
        }
    }

    private func thresholdControl(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Slider(value: value, in: range, step: 1)
                    .frame(width: 140)
                Text("\(Int(value.wrappedValue))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var updateStatusIndicator: some View {
        switch updateService.updateState {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case .updateAvailable(let version):
            Label("v\(version) available", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .lineLimit(1)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { isLaunchAtLoginRegistered },
            set: { setLaunchAtLogin($0) }
        )
    }

    private var isLaunchAtLoginRegistered: Bool {
        switch launchAtLoginStatus {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .notFound:
            false
        @unknown default:
            false
        }
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = SMAppService.mainApp.status
        settings.launchAtLogin = isLaunchAtLoginRegistered
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        launchAtLoginError = nil
        do {
            if enabled {
                try service.register()
                settings.launchAtLoginRegistrationVersion = UpdateService.currentAppVersion
            } else {
                try service.unregister()
                settings.launchAtLoginRegistrationVersion = nil
            }
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            launchAtLoginError = "Could not update Login Items: \(error.localizedDescription)"
        }
    }
}
