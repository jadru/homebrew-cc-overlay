import AppKit
import SwiftUI

/// Vertical icon-based sidebar for switching between providers and accessing settings.
struct ProviderTabSidebar: View {
    let providers: [CLIProvider]
    let activeProviders: Set<CLIProvider>
    let providerData: [CLIProvider: Double]
    @Binding var selectedProvider: CLIProvider?
    var onSettingsTapped: () -> Void

    @Namespace private var selectionNamespace
    @State private var bouncingProvider: CLIProvider?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(providers) { provider in
                    tabButton(for: provider)
                }
            }

            Spacer(minLength: 12)

            Rectangle()
                .fill(Color.dividerSubtle)
                .frame(height: 0.5)
                .padding(.horizontal, 8)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                settingsButton
                quitButton
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(width: DesignTokens.Layout.sidebarWidth)
    }

    // MARK: - Provider Tab Button

    @ViewBuilder
    private func tabButton(for provider: CLIProvider) -> some View {
        let isActive = activeProviders.contains(provider)
        let isSelected = selectedProvider == provider

        Button {
            withAnimation(DesignTokens.Animation.selection) {
                selectedProvider = provider
            }
            withAnimation(DesignTokens.Animation.bounce) {
                bouncingProvider = provider
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                if bouncingProvider == provider {
                    bouncingProvider = nil
                }
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.clear)
                        .compatGlassRoundedRect(
                            cornerRadius: 14,
                            tint: Color.brandAccent.opacity(0.18)
                        )
                        .matchedGeometryEffect(id: "providerSelection", in: selectionNamespace)
                }

                VStack(spacing: 4) {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .scaleEffect(bouncingProvider == provider ? 1.15 : 1.0)

                    Circle()
                        .fill(Color.usageTint(for: providerData[provider] ?? 100))
                        .frame(width: 5, height: 5)
                        .opacity(isActive ? 1.0 : 0.4)
                }
                .frame(width: DesignTokens.Layout.sidebarButton, height: DesignTokens.Layout.sidebarButton)
            }
            .frame(width: DesignTokens.Layout.sidebarButton, height: DesignTokens.Layout.sidebarButton)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isActive ? 1.0 : 0.35)
        .animation(DesignTokens.Animation.selection, value: isSelected)
        .animation(DesignTokens.Animation.bounce, value: bouncingProvider == provider)
        .help(provider.rawValue)
        .accessibilityLabel(provider.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Settings

    @ViewBuilder
    private var settingsButton: some View {
        utilityButton(systemName: "gear", help: "Settings", action: onSettingsTapped)
    }

    @ViewBuilder
    private var quitButton: some View {
        utilityButton(systemName: "power", help: "Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func utilityButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: DesignTokens.Layout.sidebarButton, height: DesignTokens.Layout.sidebarButton)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.surfaceElevated.opacity(0.9))
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
