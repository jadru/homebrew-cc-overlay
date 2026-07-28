import SwiftUI

struct OnboardingView: View {
    @Bindable var settings: AppSettings
    let multiService: MultiProviderUsageService
    let onComplete: () -> Void

    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CC-Overlay")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(step + 1) / 3")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: providersStep
                default: overlayStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)

            Divider()

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }

                Spacer()

                if step < 2 {
                    Button("Continue") { step += 1 }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Finish setup") {
                        settings.hasCompletedOnboarding = true
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(18)
        }
        .frame(width: 520, height: 460)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.mint)

            VStack(alignment: .leading, spacing: 10) {
                Text("Know before you run")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text("CC-Overlay keeps Claude Code and Codex headroom visible, then recommends whether to run, wait, or switch providers.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            privacyRow(
                icon: "lock.shield",
                title: "Local-first",
                detail: "No CC-Overlay account or developer-operated backend."
            )
            privacyRow(
                icon: "key.horizontal",
                title: "Explicit provider access",
                detail: "Claude Keychain access stays off until you enable it."
            )
            Spacer()
        }
    }

    private var providersStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect your coding tools")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Signed-in providers are detected locally. Unconfigured tools stay hidden from the overlay.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ForEach(CLIProvider.allCases) { provider in
                providerRow(provider)
            }

            Toggle("Read Claude OAuth rate limits", isOn: $settings.claudeOAuthEnabled)
                .onChange(of: settings.claudeOAuthEnabled) { _, _ in
                    multiService.refresh()
                }

            Text("Enabling this may trigger a macOS Keychain permission prompt. Local transcript estimates remain available without it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var overlayStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Make it yours")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("These defaults keep the recommendation visible without interrupting your work.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Toggle("Show floating overlay", isOn: $settings.showOverlay)
            Toggle("Start overlay expanded", isOn: $settings.pillAlwaysExpanded)
                .disabled(!settings.showOverlay)
            Toggle("Usage threshold alerts", isOn: $settings.costAlertEnabled)
            HStack(spacing: 10) {
                Image(systemName: "command")
                Text("Toggle the overlay any time with Command-Shift-A.")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .compatGlassRoundedRect(cornerRadius: 10, interactive: false, tint: Color.mint.opacity(0.08))

            Spacer()
        }
    }

    private func providerRow(_ provider: CLIProvider) -> some View {
        let data = multiService.usageData(for: provider)
        let isDetected = multiService.activeProviders.contains(provider)

        return HStack(spacing: 12) {
            ProviderIconView(provider: provider, size: 22)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Text(data.error ?? (data.isAvailable ? "Live usage ready" : isDetected ? "Detected - waiting for usage" : "Not detected"))
                    .font(.system(size: 10))
                    .foregroundStyle(data.error == nil ? Color.secondary : Color.orange)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: data.isAvailable ? "checkmark.circle.fill" : isDetected ? "clock.fill" : "minus.circle")
                .foregroundStyle(data.isAvailable ? .mint : .secondary)
        }
        .padding(12)
        .compatGlassRoundedRect(cornerRadius: 11, interactive: false, tint: Color.secondary.opacity(0.04))
    }

    private func privacyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.mint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}
