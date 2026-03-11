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
    @State private var keyMonitor: Any?

    private var activeProviderSet: Set<CLIProvider> {
        Set(multiService.activeProviders)
    }

    private var providerUsageValues: [CLIProvider: Double] {
        Dictionary(
            uniqueKeysWithValues: CLIProvider.allCases.map { provider in
                (provider, multiService.usageData(for: provider).remainingPercentage)
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            ProviderTabSidebar(
                providers: CLIProvider.allCases,
                activeProviders: activeProviderSet,
                providerData: providerUsageValues,
                selectedProvider: $selectedProvider,
                onSettingsTapped: { onOpenSettings?() }
            )

            Rectangle()
                .fill(Color.dividerSubtle)
                .frame(width: 0.5)
                .padding(.vertical, 10)

            contentArea
        }
        .frame(width: DesignTokens.Layout.menuBarPanelWidth)
        .frame(
            minHeight: DesignTokens.Layout.menuBarPanelMinHeight,
            maxHeight: DesignTokens.Layout.menuBarPanelMaxHeight,
            alignment: .topLeading
        )
        .onAppear {
            DebugFlowLogger.shared.log(
                stage: .display,
                message: "menuBar.appear",
                details: ["active": activeProviderSet.map(\.rawValue).joined(separator: ",")]
            )

            if selectedProvider == nil {
                selectedProvider = multiService.activeProviders.first ?? CLIProvider.allCases.first
            }

            installKeyMonitorIfNeeded()
        }
        .onDisappear(perform: removeKeyMonitor)
        .onChange(of: multiService.activeProviders) { _, newProviders in
            if let current = selectedProvider, !newProviders.contains(current) {
                selectedProvider = newProviders.first ?? CLIProvider.allCases.first
            }

            DebugFlowLogger.shared.log(
                stage: .display,
                message: "menuBar.providers.changed",
                details: ["providers": newProviders.map(\.rawValue).joined(separator: ",")]
            )
        }
        .onChange(of: selectedProvider) { _, newProvider in
            DebugFlowLogger.shared.log(
                stage: .display,
                message: "menuBar.provider.selected",
                details: ["provider": newProvider?.rawValue ?? "none"]
            )
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            VStack(spacing: 12) {
                UpdateBannerView(updateService: updateService)

                contentHeader

                if let provider = selectedProvider {
                    let data = multiService.usageData(for: provider)
                    let allData = CLIProvider.allCases.map { ($0, multiService.usageData(for: $0)) }
                    ProviderSectionView(
                        data: data,
                        allProviderData: allData,
                        selectedProvider: $selectedProvider,
                        activeProviders: activeProviderSet,
                        settings: settings
                    )
                } else {
                    noProvidersView
                }

                footerSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .padding(.horizontal, 14)
        .animation(DesignTokens.Animation.selection, value: selectedProvider)
    }

    // MARK: - Content Header

    @ViewBuilder
    private var contentHeader: some View {
        if let provider = selectedProvider {
            let data = multiService.usageData(for: provider)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 30, height: 30)
                            .compatGlassCircle(tint: Color.brandAccent.opacity(0.14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.rawValue)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                            Text(data.isAvailable ? "Live usage snapshot" : "Setup required")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    actionGroup
                        .fixedSize()
                }

                if let plan = compactPlanName(data.planName) {
                    Text(plan)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.brandAccent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.brandAccent.opacity(0.16))
                        )
                        .frame(maxWidth: 220, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Export Menu

    @ViewBuilder
    private var exportMenu: some View {
        Menu {
            Button("Copy Summary") {
                guard let provider = selectedProvider else { return }
                let data = multiService.usageData(for: provider)
                let summary = UsageExportService.markdownSummary(data: data)
                UsageExportService.copyToClipboard(summary)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.button)
        .fixedSize()
    }

    // MARK: - Refresh Button

    @ViewBuilder
    private var refreshButton: some View {
        Button(action: refreshData) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
                .foregroundStyle(showRefreshSuccess ? .green : .primary)
                .rotationEffect(.degrees(refreshRotation))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("Refresh usage data")
        .accessibilityHint("Fetches latest provider usage and limits")
        .accessibilityValue(multiService.isLoading ? "Refreshing" : "Idle")
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

    @ViewBuilder
    private var actionGroup: some View {
        HStack(spacing: 4) {
            exportMenu
            refreshButton
        }
        .padding(4)
        .compatGlassCapsule(interactive: true, tint: Color.brandAccent.opacity(0.08))
    }

    // MARK: - No Providers

    @ViewBuilder
    private var noProvidersView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.brandAccent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.brandAccent.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("No CLI providers detected")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Install one of the CLIs below, then refresh.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(CLIProvider.allCases) { provider in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: provider.iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.brandAccent)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                            Text(provider.setupHint)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardBackground(useGlass: true, cornerRadius: 16)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.dividerSubtle)
                .frame(height: 0.5)
                .padding(.bottom, 4)

            if let lastRefresh = multiService.lastRefresh {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
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

    private func refreshData() {
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "menuBar.refresh.tapped",
            details: ["provider": selectedProvider?.rawValue ?? "none"]
        )
        multiService.refresh()
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.isEmpty || flags == [.shift] else { return false }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }

        switch key {
        case "1", "2", "3":
            let providers = CLIProvider.allCases
            guard let index = Int(key), providers.indices.contains(index - 1) else { return false }
            withAnimation(DesignTokens.Animation.selection) {
                selectedProvider = providers[index - 1]
            }
            return true
        case "r":
            refreshData()
            return true
        default:
            return false
        }
    }

    private func compactPlanName(_ planName: String?) -> String? {
        guard let planName, !planName.isEmpty else { return nil }
        if let start = planName.firstIndex(of: "(") {
            return String(planName[..<start]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if planName.count <= 22 {
            return planName
        }
        return String(planName.prefix(20)) + "…"
    }
}
