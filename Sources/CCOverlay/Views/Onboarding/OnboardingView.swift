import SwiftUI

struct OnboardingView: View {
    @Bindable var settings: AppSettings
    let multiService: MultiProviderUsageService
    let onComplete: () -> Void

    @State private var step = 0
    @State private var recoveryError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            ScrollView {
                stepContent
                    .id(step)
                    .transition(stepTransition)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(30)
            }
            .scrollIndicators(.never)

            Divider()

            HStack {
                if step > 0 {
                    Button("Back") { changeStep(to: step - 1) }
                }

                Spacer()

                if step < 2 {
                    Button("Continue") { changeStep(to: step + 1) }
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
        .frame(width: 520, height: 520)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: providersStep
        default: overlayStep
        }
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private var stepAnimation: Animation {
        reduceMotion ? DesignTokens.Animation.reducedFeedback : DesignTokens.Animation.reveal
    }

    private func changeStep(to nextStep: Int) {
        withAnimation(stepAnimation) {
            step = nextStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.mint)

            VStack(alignment: .leading, spacing: 10) {
                Text("Know before you run")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text("CC-Overlay keeps your Mac's system capacity and Codex or Claude Code headroom visible before an intensive run.")
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
                Text("Codex is the default recommendation. Signed-in providers are detected locally, and unconfigured tools stay hidden.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(CLIProvider.productOrder) { provider in
                providerRow(provider)
            }

            if let recoveryError {
                Label(recoveryError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                Text("The compact bar stays visible while you work. Click a metric for quick details, or use its dashboard button for the full system and AI view.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Picker("Show overlay", selection: $settings.overlayVisibilityMode) {
                ForEach(OverlayVisibilityMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Toggle("Show floating overlay", isOn: $settings.showOverlay)
            Toggle("Click through", isOn: $settings.pillClickThrough)
                .disabled(!settings.showOverlay)

            Text("System samples stay on your Mac. Alerts, provider access, terminal behavior, and other preferences remain in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
        let status = multiService.activationStatus(for: provider)

        return HStack(spacing: 12) {
            ProviderIconView(provider: provider, size: 22)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Text(status.title)
                    .font(.system(size: 10))
                    .foregroundStyle(status.kind == .failed ? Color.orange : Color.secondary)
                    .lineLimit(1)
                Text(status.detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            if status.kind == .ready {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.mint)
            } else if let command = status.recoveryCommand {
                Button(status.kind == .cliMissing ? "Install" : "Sign in") {
                    runRecovery(command)
                }
                .controlSize(.small)
            }

            Button {
                multiService.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Recheck provider")
            .accessibilityLabel("Recheck \(provider.rawValue)")
        }
        .padding(12)
        .compatGlassRoundedRect(cornerRadius: 11, interactive: false, tint: Color.secondary.opacity(0.04))
    }

    private func runRecovery(_ command: String) {
        do {
            try TerminalLauncher.launch(
                command: command,
                workingDirectory: FileManager.default.homeDirectoryForCurrentUser,
                terminal: settings.preferredTerminal
            )
            recoveryError = nil
            Task {
                try? await Task.sleep(for: .seconds(2))
                multiService.refresh()
            }
        } catch {
            recoveryError = error.localizedDescription
        }
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
