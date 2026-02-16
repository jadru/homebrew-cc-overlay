import AppKit
import SwiftUI

struct MenuBarView: View {
    let multiService: MultiProviderUsageService
    @Bindable var settings: AppSettings
    let updateService: UpdateService
    var onOpenSettings: (() -> Void)?

    @State private var selectedProvider: CLIProvider?
    @State private var showRefreshSuccess = false
    @State private var refreshRotation: Double = 0

    private var activeProviderSet: Set<CLIProvider> {
        Set(multiService.activeProviders)
    }

    var body: some View {
        HStack(spacing: 0) {
            ProviderTabSidebar(
                providers: CLIProvider.allCases,
                activeProviders: activeProviderSet,
                selectedProvider: $selectedProvider,
                onSettingsTapped: { onOpenSettings?() }
            )

            Divider()
                .padding(.vertical, 8)

            contentArea
        }
        .frame(width: 340)
        .onAppear {
            if selectedProvider == nil {
                selectedProvider = multiService.activeProviders.first ?? CLIProvider.allCases.first
            }
        }
        .onChange(of: multiService.activeProviders) { _, newProviders in
            if let current = selectedProvider, !CLIProvider.allCases.contains(current) {
                selectedProvider = newProviders.first ?? CLIProvider.allCases.first
            }
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 12) {
            UpdateBannerView(updateService: updateService)

            contentHeader

            if let provider = selectedProvider {
                let data = multiService.usageData(for: provider)
                ProviderSectionView(
                    data: data,
                    settings: settings
                )
            } else {
                noProvidersView
            }

            footerSection
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 14)
    }

    // MARK: - Content Header

    @ViewBuilder
    private var contentHeader: some View {
        if let provider = selectedProvider {
            let data = multiService.usageData(for: provider)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                    if let plan = data.planName {
                        Text(plan)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                refreshButton
            }
        }
    }

    // MARK: - Refresh Button

    @ViewBuilder
    private var refreshButton: some View {
        Button(action: { multiService.refresh() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
                .foregroundStyle(showRefreshSuccess ? .green : .primary)
                .rotationEffect(.degrees(refreshRotation))
        }
        .buttonStyle(.borderless)
        .focusable(false)
        .accessibilityHidden(true)
        .compatGlassCircle(interactive: true)
        .onChange(of: multiService.isLoading) { _, isLoading in
            if isLoading {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    refreshRotation = 360
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    refreshRotation = 0
                }
            }
        }
        .onChange(of: multiService.lastRefresh) { _, newValue in
            guard newValue != nil, multiService.error == nil else { return }
            withAnimation(.easeIn(duration: 0.15)) {
                showRefreshSuccess = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                showRefreshSuccess = false
            }
        }
    }

    // MARK: - No Providers

    @ViewBuilder
    private var noProvidersView: some View {
        Spacer()
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No CLI providers detected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Install Claude Code, Codex, or Gemini CLI to get started")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        Spacer()
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 4) {
            if let lastRefresh = multiService.lastRefresh {
                Text("Updated \(lastRefresh, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }

            if let error = multiService.error {
                ErrorBannerView(
                    error: AppError.from(error),
                    onRetry: { multiService.refresh() },
                    compact: false
                )
            }
        }
    }
}
