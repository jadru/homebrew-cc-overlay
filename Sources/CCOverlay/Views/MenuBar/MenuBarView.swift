import AppKit
import SwiftUI

struct MenuBarView: View {
    enum PanelState: Equatable {
        case ready
        case loading
        case failed
        case noProviders
        case noUsage
    }

    let multiService: MultiProviderUsageService
    @Bindable var settings: AppSettings
    let updateService: UpdateService
    var onOpenSettings: (() -> Void)?

    @State private var selectedProvider: CLIProvider?
    @State private var keyMonitor: Any?

    private var availableProviders: [CLIProvider] {
        multiService.availableProviders
    }

    private var activeProviderSet: Set<CLIProvider> {
        Set(availableProviders)
    }

    private var displayedProvider: CLIProvider? {
        if let selectedProvider, availableProviders.contains(selectedProvider) {
            return selectedProvider
        }
        return availableProviders.first
    }

    private var panelState: PanelState {
        Self.resolvePanelState(
            activeProviders: multiService.activeProviders,
            availableProviders: availableProviders,
            isLoading: multiService.isLoading,
            hasError: multiService.error != nil
        )
    }

    var body: some View {
        contentArea
        .frame(width: DesignTokens.Layout.menuBarPanelWidth)
        .frame(
            minHeight: panelMinHeight,
            maxHeight: DesignTokens.Layout.menuBarPanelMaxHeight,
            alignment: .topLeading
        )
        .onAppear {
            DebugFlowLogger.shared.log(
                stage: .display,
                message: "menuBar.appear",
                details: ["active": availableProviders.map(\.rawValue).joined(separator: ",")]
            )

            if selectedProvider == nil {
                selectedProvider = availableProviders.first
            }

            installKeyMonitorIfNeeded()
        }
        .onDisappear(perform: removeKeyMonitor)
        .onChange(of: availableProviders) { _, newProviders in
            if selectedProvider.map({ newProviders.contains($0) }) != true {
                selectedProvider = newProviders.first
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

    private var panelMinHeight: CGFloat {
        guard panelState == .ready, let provider = displayedProvider else {
            return DesignTokens.Layout.menuBarPanelEmptyMinHeight
        }
        return Self.readyPanelMinHeight(for: multiService.usageData(for: provider))
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelContent

                UpdateBannerView(updateService: updateService)
                footerSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    // MARK: - Header

    @ViewBuilder
    private var panelContent: some View {
        switch panelState {
        case .ready:
            if let provider = displayedProvider {
                commandHeader(for: provider)
                if availableProviders.count > 1 {
                    providerRail
                }
                ProviderSectionView(data: multiService.usageData(for: provider))
            }
        case .loading, .failed, .noProviders, .noUsage:
            unavailableContent
        }
    }

    private func commandHeader(for provider: CLIProvider) -> some View {
        let data = multiService.usageData(for: provider)
        return HStack(alignment: .center, spacing: 12) {
            ProviderIconView(provider: provider, size: 18, fallbackColor: .primary)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(provider.rawValue)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                        .layoutPriority(1)

                    statusBadge(for: data)
                }

                Text(headerSubtitle(for: data))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Unavailable State

    private var unavailableContent: some View {
        VStack(spacing: 0) {
            unavailableMessage
                .frame(maxWidth: .infinity, minHeight: 150)

            HStack(spacing: 8) {
                Button(action: refreshData) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(panelState == .loading)

                Button(action: { onOpenSettings?() }) {
                    Label("Settings", systemImage: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                overflowMenu
            }
        }
    }

    @ViewBuilder
    private var unavailableMessage: some View {
        let presentation = unavailablePresentation

        VStack(spacing: 10) {
            if panelState == .loading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 34, height: 34)
            } else {
                Image(systemName: presentation.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(presentation.tint)
                    .frame(width: 34, height: 34)
                    .compatGlassCircle(tint: presentation.tint.opacity(0.08))
            }

            VStack(spacing: 4) {
                Text(presentation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(presentation.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 300)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var unavailablePresentation: (title: String, message: String, icon: String, tint: Color) {
        switch panelState {
        case .ready:
            return ("Usage ready", "Current provider usage is available.", "checkmark", .mint)
        case .loading:
            return ("Loading usage", "Fetching the latest provider limits.", "arrow.clockwise", .secondary)
        case .failed:
            let error = AppError.from(multiService.error ?? "Usage could not be loaded.")
            return (error.title, error.message, error.icon, .red)
        case .noProviders:
            return (
                "No providers found",
                "CC-Overlay couldn't find a signed-in Claude Code or Codex CLI.",
                "terminal",
                .secondary
            )
        case .noUsage:
            return (
                "No current usage",
                "Connected providers have no current usage window to display.",
                "chart.bar.xaxis",
                .secondary
            )
        }
    }

    @ViewBuilder
    private var providerRail: some View {
        let allData = availableProviders.map { ($0, multiService.usageData(for: $0)) }
        ProviderSummaryCardView(
            allProviderData: allData,
            selectedProvider: $selectedProvider,
            activeProviders: activeProviderSet,
            size: .compact,
            showsCardBackground: false
        )
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statusBadge(for data: ProviderUsageData) -> some View {
        let status = statusInfo(for: data)

        HStack(spacing: 4) {
            Circle()
                .fill(status.tint)
                .frame(width: 5, height: 5)
            Text(status.label)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(status.tint)
    }

    private func statusTint(for data: ProviderUsageData) -> Color {
        Color.usageTint(for: data.remainingPercentage)
    }

    private func statusInfo(for data: ProviderUsageData) -> (label: String, tint: Color) {
        if data.error != nil {
            return ("Refresh failed", .red)
        }
        if multiService.isStale(lastRefresh: data.lastRefresh) {
            return ("Stale", .orange)
        }
        if data.isEstimated {
            return ("Estimate", .secondary)
        }
        return ("Live", statusTint(for: data))
    }

    private var footerStatus: (label: String, tint: Color) {
        if multiService.error != nil {
            return ("Refresh failed", .red)
        }
        if multiService.hasStaleData {
            return ("Stale", .orange)
        }
        return ("Live", .mint)
    }

    private func headerSubtitle(for data: ProviderUsageData) -> String {
        if let plan = compactPlanName(data.planName) {
            return plan
        }
        return "\(NumberFormatting.formatPercentage(data.remainingPercentage)) left in \(data.primaryWindowLabel)"
    }

    private var overflowMenu: some View {
        Menu {
            if let provider = displayedProvider {
                Button {
                    let data = multiService.usageData(for: provider)
                    UsageExportService.copyToClipboard(UsageExportService.markdownSummary(data: data))
                } label: {
                    Label("Copy summary", systemImage: "square.and.arrow.up")
                }
            }

            Button(action: refreshData) {
                Label("Refresh usage", systemImage: "arrow.clockwise")
            }
            .disabled(multiService.isLoading)

            Divider()

            Button(action: { onOpenSettings?() }) {
                Label("Settings", systemImage: "gearshape")
            }

            Button(role: .destructive, action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit CC-Overlay", systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityLabel("More actions")
        .help("More actions")
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        if !availableProviders.isEmpty {
            let status = footerStatus

            VStack(spacing: 8) {
                Rectangle()
                    .fill(Color.dividerSubtle)
                    .frame(height: 0.5)

                HStack(spacing: 5) {
                    if let lastRefresh = multiService.lastRefresh {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("Updated \(lastRefresh, style: .relative) ago")
                            .font(.system(size: 10))
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(status.tint)
                            .frame(width: 5, height: 5)
                        Text(status.label)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                    overflowMenu
                }
                .foregroundStyle(.tertiary)

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

    private func refreshData() {
        guard !multiService.isLoading else { return }

        DebugFlowLogger.shared.log(
            stage: .display,
            message: "menuBar.refresh.tapped",
            details: ["provider": selectedProvider?.rawValue ?? "none"]
        )
        multiService.refresh()
    }

    static func resolvePanelState(
        activeProviders: [CLIProvider],
        availableProviders: [CLIProvider],
        isLoading: Bool,
        hasError: Bool
    ) -> PanelState {
        if !availableProviders.isEmpty {
            return .ready
        }
        if isLoading {
            return .loading
        }
        if hasError {
            return .failed
        }
        if activeProviders.isEmpty {
            return .noProviders
        }
        return .noUsage
    }

    nonisolated static func readyPanelMinHeight(for data: ProviderUsageData) -> CGFloat {
        let primaryWindowCount = UsageTimelineView.primaryWindowLabels(from: data.rateLimitBuckets).count
        let hasVisibleAdditionalLimits = !UsageTimelineView.visibleAdditionalBuckets(
            from: data.rateLimitBuckets
        ).isEmpty

        if primaryWindowCount <= 1 && !hasVisibleAdditionalLimits {
            return DesignTokens.Layout.menuBarPanelCompactMinHeight
        }
        return DesignTokens.Layout.menuBarPanelMinHeight
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
            let providers = availableProviders
            guard let index = Int(key), providers.indices.contains(index - 1) else { return false }
            selectedProvider = providers[index - 1]
            return true
        case "r":
            guard !multiService.isLoading else { return true }
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
