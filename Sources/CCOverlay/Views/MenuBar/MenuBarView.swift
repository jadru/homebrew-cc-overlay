import AppKit
import SwiftUI

struct MenuBarView: View {
    let multiService: MultiProviderUsageService
    let sessionMonitor: SessionMonitor
    let usageHistoryService: UsageHistoryService?
    @Bindable var settings: AppSettings
    let updateService: UpdateService
    var onOpenSettings: (() -> Void)?

    @State private var selectedProvider: CLIProvider?
    @State private var showRefreshSuccess = false
    @State private var refreshRotation: Double = 0
    @State private var keyboardMonitor: Any?

    private var activeProviderSet: Set<CLIProvider> {
        Set(multiService.activeProviders)
    }

    private var navigableProviders: [CLIProvider] {
        let enabledProviders = CLIProvider.allCases.filter { settings.isEnabled($0) && !multiService.isProviderPaused($0) }
        let activeEnabledProviders = enabledProviders.filter { activeProviderSet.contains($0) }
        return activeEnabledProviders.isEmpty ? enabledProviders : activeEnabledProviders
    }

    private var isHistoryUnavailable: Bool {
        usageHistoryService == nil
    }

    private var providerErrors: [CLIProvider: String] {
        Dictionary(uniqueKeysWithValues: CLIProvider.allCases.compactMap { provider in
            let err = multiService.usageData(for: provider).error
            guard let err else { return nil }
            return (provider, err)
        })
    }

    var body: some View {
        HStack(spacing: 0) {
            ProviderTabSidebar(
                providers: CLIProvider.allCases,
                activeProviders: activeProviderSet,
                pausedProviders: Set(CLIProvider.allCases.filter { multiService.isProviderPaused($0) }),
                providerErrors: providerErrors,
                selectedProvider: $selectedProvider,
                onSettingsTapped: { onOpenSettings?() },
                onPauseResumeTapped: { provider in
                    multiService.setProviderPaused(provider, paused: !multiService.isProviderPaused(provider))
                }
            )

            Divider()
                .padding(.vertical, 8)

            contentArea
        }
        .frame(width: 380)
        .frame(minHeight: 700)
        .onAppear {
            initializeView()
        }
        .onDisappear {
            stopKeyboardMonitor()
        }
        .onChange(of: multiService.activeProviders) { _, newProviders in
            if let current = selectedProvider, !newProviders.contains(current) {
                selectedProvider = (newProviders.first ?? CLIProvider.allCases.first(where: settings.isEnabled)) ?? CLIProvider.allCases.first
            }
            if selectedProvider == nil {
                selectedProvider = newProviders.first ?? CLIProvider.allCases.first(where: settings.isEnabled)
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
    private let maxSectionHeight: CGFloat = 1000

    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 12) {
            UpdateBannerView(updateService: updateService)

            contentHeader

            if let provider = selectedProvider {
                let data = multiService.usageData(for: provider)
                ScrollView {
                    ProviderSectionView(
                        data: data,
                        activeSessions: provider == .claudeCode ? sessionMonitor.activeSessions : []
                    )
                }
                .frame(maxHeight: maxSectionHeight)
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

                exportMenu
                refreshButton
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
                let summary = UsageExportService.markdownSummary(data: data, projects: data.projectCosts)
                UsageExportService.copyToClipboard(summary)
            }

            Divider()

            Button("Copy Usage CSV") {
                copyUsageCSV()
            }
            .disabled(isHistoryUnavailable || !hasHistoryForExport)

            Button("Save Usage CSV...") {
                Task {
                    await saveUsageCSV()
                }
            }
            .disabled(isHistoryUnavailable || !hasHistoryForExport)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)

                if isHistoryUnavailable {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                        .offset(x: 8, y: -8)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var hasHistoryForExport: Bool {
        guard !isHistoryUnavailable, let snapshots = currentSnapshots() else { return false }
        return !snapshots.isEmpty
    }

    private var historyBannerError: AppError? {
        if isHistoryUnavailable {
            return .historyStorageUnavailable
        }

        guard let provider = selectedProvider else { return nil }
        guard let snapshots = currentSnapshots(), !snapshots.isEmpty else {
            return .historyEmpty(provider: provider.rawValue)
        }

        return nil
    }

    private func copyUsageCSV() {
        guard let snapshots = currentSnapshots(), !snapshots.isEmpty else { return }
        let csv = UsageExportService.csvExport(snapshots: snapshots)
        UsageExportService.copyToClipboard(csv)
    }

    private func saveUsageCSV() async {
        guard let snapshots = currentSnapshots(), !snapshots.isEmpty else { return }
        let csv = UsageExportService.csvExport(snapshots: snapshots)
        await UsageExportService.saveCSVFile(csv)
    }

    private func currentSnapshots() -> [UsageSnapshot]? {
        guard let provider = selectedProvider else { return nil }
        return usageHistoryService?.dailySnapshots(for: provider, days: 7)
    }

    // MARK: - Refresh Button

    @ViewBuilder
    private var refreshButton: some View {
        Button(action: triggerRefresh) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
                .foregroundStyle(showRefreshSuccess ? .green : .primary)
                .rotationEffect(.degrees(refreshRotation))
        }
        .buttonStyle(.borderless)
        .focusable(false)
        .accessibilityLabel("Refresh usage data")
        .accessibilityHint("Fetches latest provider usage and limits")
        .accessibilityValue(multiService.isLoading ? "Refreshing" : "Idle")
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

    private func triggerRefresh() {
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "menuBar.refresh.tapped",
            details: ["provider": selectedProvider?.rawValue ?? "none"]
        )
        multiService.refresh()
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
            if let historyBannerError {
                ErrorBannerView(error: historyBannerError, compact: true)
            }

            if let lastRefresh = multiService.lastRefresh {
                Text("Updated \(lastRefresh, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }

            if let error = multiService.error {
                ErrorBannerView(
                    error: AppError.from(error),
                    onRetry: triggerRefresh,
                    compact: false
                )
            }
        }
    }
}

extension MenuBarView {
    private func initializeView() {
        DebugFlowLogger.shared.log(
            stage: .display,
            message: "menuBar.appear",
            details: ["active": activeProviderSet.map(\.rawValue).joined(separator: ",")]
        )

        if selectedProvider == nil {
            selectedProvider = navigableProviders.first ?? activeProviderSet.first ?? CLIProvider.allCases.first
        }

        startKeyboardMonitor()
    }

    private func startKeyboardMonitor() {
        guard keyboardMonitor == nil else { return }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func stopKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
        keyboardMonitor = nil
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags
        let hasBlockingModifiers = modifiers.intersection([.command, .control, .option, .function, .capsLock]).isEmpty == false

        if hasBlockingModifiers {
            return false
        }

        switch event.keyCode {
        case 126: // Up
            moveProviderSelection(delta: -1)
            return true
        case 125: // Down
            moveProviderSelection(delta: 1)
            return true
        case 15: // R
            if event.charactersIgnoringModifiers?.lowercased() == "r" {
                triggerRefresh()
                return true
            }
            return false
        default:
            return false
        }
    }

    private func moveProviderSelection(delta: Int) {
        guard !navigableProviders.isEmpty else { return }

        if let current = selectedProvider, let index = navigableProviders.firstIndex(of: current) {
            let newIndex = (index + delta).modulo(navigableProviders.count)
            selectedProvider = navigableProviders[newIndex]
            return
        }

        selectedProvider = navigableProviders.first
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
