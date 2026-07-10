import AppKit
import SwiftUI

struct MenuBarView: View {
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

    var body: some View {
        contentArea
        .frame(width: DesignTokens.Layout.menuBarPanelWidth)
        .frame(
            minHeight: availableProviders.isEmpty ? 0 : DesignTokens.Layout.menuBarPanelMinHeight,
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

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let provider = selectedProvider, availableProviders.contains(provider) {
                    commandHeader
                    if availableProviders.count > 1 {
                        providerRail
                    }
                    let data = multiService.usageData(for: provider)
                    ProviderSectionView(data: data)
                } else {
                    overflowMenu
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

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
    private var commandHeader: some View {
        if let provider = selectedProvider {
            let data = multiService.usageData(for: provider)
            HStack(alignment: .center, spacing: 12) {
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
            if let provider = selectedProvider {
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
        }
        .accessibilityLabel("More actions")
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
            let providers = availableProviders
            guard let index = Int(key), providers.indices.contains(index - 1) else { return false }
            selectedProvider = providers[index - 1]
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
