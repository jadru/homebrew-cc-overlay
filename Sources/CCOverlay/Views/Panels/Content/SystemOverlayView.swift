import SwiftUI

private enum SystemMetricDetail: String, Identifiable {
    case cpu
    case ram
    case network
    case ssd
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .ram: "RAM"
        case .network: "Network"
        case .ssd: "SSD"
        case .ai: "AI usage"
        }
    }

    var systemImage: String {
        switch self {
        case .cpu: "cpu"
        case .ram: "memorychip"
        case .network: "arrow.up.arrow.down"
        case .ssd: "internaldrive"
        case .ai: "wand.and.stars"
        }
    }
}

private enum DockerStoragePresentation: Hashable {
    case empty
    case loading
    case snapshot
}

struct SystemOverlayView: View {
    let multiService: MultiProviderUsageService
    let systemMetrics: SystemMetricsService
    let dockerStorage: DockerStorageService
    @Bindable var settings: AppSettings
    let interactionState: OverlayInteractionState
    let onHideOverlay: () -> Void
    let onQuitApplication: () -> Void
    let onShowDashboard: () -> Void
    var onSizeChange: ((CGSize) -> Void)?

    @State private var selectedDetail: SystemMetricDetail?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var sample: SystemMetricsSample? { systemMetrics.currentSample }

    private var compactAIProviders: [OverlayUsagePresentation.CompactProviderUsage] {
        OverlayUsagePresentation.compactProviders(
            activeProviders: multiService.activeProviders,
            usageData: multiService.usageData(for:)
        )
    }

    var body: some View {
        SystemOverlayLifecycleContainer(
            content: compactSurface,
            onSizeChange: onSizeChange,
            accessibilityValue: accessibilityValue
        )
        .onChange(of: interactionState.detailDismissalGeneration) { _, _ in
            selectedDetail = nil
        }
        .onDisappear {
            interactionState.setDetailPopoverPresented(false)
        }
    }

    private var compactSurface: some View {
        overlayLayout
            .systemMonitorSurface(cornerRadius: 10, tint: overallTint.opacity(0.08))
            .contextMenu {
                Button(action: presentDashboard) {
                    Label(OverlayContextMenuAction.showDashboard.title, systemImage: "rectangle.3.group")
                }

                Menu("Layout") {
                    ForEach(OverlayPresentation.allCases) { presentation in
                        Button {
                            selectOverlayPresentation(presentation)
                        } label: {
                            Label(
                                presentation.label,
                                systemImage: settings.overlayPresentation == presentation
                                    ? "checkmark"
                                    : "rectangle"
                            )
                        }
                    }
                }

                Divider()

                Button(action: onHideOverlay) {
                    Label(OverlayContextMenuAction.hideOverlay.title, systemImage: "eye.slash")
                }

                Divider()

                Button(role: .destructive, action: onQuitApplication) {
                    Label(OverlayContextMenuAction.quitApplication.title, systemImage: "power")
                }
            }
    }

    @ViewBuilder
    private var overlayLayout: some View {
        switch settings.overlayPresentation {
        case .horizontal:
            horizontalLayout
        case .vertical:
            verticalLayout
        case .twoColumn:
            twoColumnLayout
        }
    }

    private var horizontalLayout: some View {
        HStack(spacing: 9) {
            compactMetric(
                .cpu, title: "CPU",
                value: sample?.cpuUsagePercentage.map(NumberFormatting.formatPercentage) ?? "—",
                tint: cpuTint)
            Divider().frame(height: 20)
            compactMetric(
                .ram, title: "RAM",
                value: sample?.memory.usagePercentage.map(NumberFormatting.formatPercentage) ?? "—",
                tint: memoryTint)
            Divider().frame(height: 20)
            compactMetric(.network, title: "NET", value: compactNetwork, tint: .blue)
            Divider().frame(height: 20)
            compactMetric(.ssd, title: "SSD", value: storageValue, tint: .indigo)
            Divider().frame(height: 20)
            compactAIUsage
            Divider().frame(height: 20)
            dashboardButton
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
    }

    private var verticalLayout: some View {
        VStack(spacing: 0) {
            rowMetric(.cpu, title: "CPU", value: sample?.cpuUsagePercentage.map(NumberFormatting.formatPercentage) ?? "—", tint: cpuTint)
            Divider()
            rowMetric(.ram, title: "RAM", value: sample?.memory.usagePercentage.map(NumberFormatting.formatPercentage) ?? "—", tint: memoryTint)
            Divider()
            rowMetric(.network, title: "Network", value: compactNetwork, tint: .blue)
            Divider()
            rowMetric(.ssd, title: "SSD", value: storageValue, tint: .indigo)
            Divider()
            rowAIUsage
            Divider()
            dashboardRowButton
        }
        .padding(7)
    }

    private var twoColumnLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                compactMetric(.cpu, title: "CPU", value: sample?.cpuUsagePercentage.map(NumberFormatting.formatPercentage) ?? "—", tint: cpuTint)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                Divider().frame(height: 24)
                compactMetric(.ram, title: "RAM", value: sample?.memory.usagePercentage.map(NumberFormatting.formatPercentage) ?? "—", tint: memoryTint)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            }
            Divider()
            HStack(spacing: 0) {
                compactMetric(.network, title: "NET", value: compactNetwork, tint: .blue)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                Divider().frame(height: 24)
                compactMetric(.ssd, title: "SSD", value: storageValue, tint: .indigo)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            }
            Divider()
            HStack(spacing: 0) {
                compactAIUsage
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                Divider().frame(height: 24)
                dashboardButton
                    .frame(maxWidth: .infinity, minHeight: 26)
            }
        }
        .padding(7)
    }

    private var dashboardButton: some View {
        Button {
            guard !interactionState.consumeSuppressedPrimaryAction() else { return }
            presentDashboard()
        } label: {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(SystemOverlayMetricButtonStyle(interactionState: interactionState))
        .accessibilityLabel("Show system dashboard")
        .help("Show system dashboard")
    }

    private var compactAIUsage: some View {
        Button {
            guard !interactionState.consumeSuppressedPrimaryAction() else { return }
            let nextDetail: SystemMetricDetail? = selectedDetail == .ai ? nil : .ai
            selectedDetail = nextDetail
            interactionState.setDetailPopoverPresented(nextDetail != nil)
        } label: {
            HStack(spacing: 5) {
                if compactAIProviders.isEmpty {
                    compactAIValue(label: "AI", value: "—", tint: .secondary)
                } else {
                    ForEach(compactAIProviders) { providerUsage in
                        compactAIValue(
                            label: providerUsage.provider.shortLabel,
                            value: providerUsage.value.displayText,
                            tint: compactAITint(for: providerUsage.value)
                        )
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SystemOverlayMetricButtonStyle(interactionState: interactionState))
        .accessibilityLabel("Show AI usage details")
        .accessibilityValue(compactAIAccessibilityValue)
        .popover(isPresented: detailBinding(for: .ai), arrowEdge: .bottom) {
            metricDetailPopover(.ai)
        }
    }

    private func compactAIValue(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(minWidth: 30, alignment: .leading)
    }

    private func presentDashboard() {
        selectedDetail = nil
        interactionState.setDetailPopoverPresented(false)
        onShowDashboard()
    }

    private func selectOverlayPresentation(_ presentation: OverlayPresentation) {
        selectedDetail = nil
        interactionState.setDetailPopoverPresented(false)
        settings.overlayPresentation = presentation
    }

    private func compactMetric(
        _ detail: SystemMetricDetail,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        Button {
            guard !interactionState.consumeSuppressedPrimaryAction() else { return }
            let nextDetail = selectedDetail == detail ? nil : detail
            selectedDetail = nextDetail
            interactionState.setDetailPopoverPresented(nextDetail != nil)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
            }
            .frame(minWidth: title == "NET" ? 38 : 30, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(SystemOverlayMetricButtonStyle(interactionState: interactionState))
        .accessibilityLabel("Show \(detail.title) details")
        .accessibilityValue(value)
        .popover(isPresented: detailBinding(for: detail), arrowEdge: .bottom) {
            metricDetailPopover(detail)
        }
    }

    private func rowMetric(
        _ detail: SystemMetricDetail,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        Button {
            guard !interactionState.consumeSuppressedPrimaryAction() else { return }
            let nextDetail = selectedDetail == detail ? nil : detail
            selectedDetail = nextDetail
            interactionState.setDetailPopoverPresented(nextDetail != nil)
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            .frame(minHeight: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(SystemOverlayMetricButtonStyle(interactionState: interactionState))
        .accessibilityLabel("Show \(detail.title) details")
        .accessibilityValue(value)
        .popover(isPresented: detailBinding(for: detail), arrowEdge: .trailing) {
            metricDetailPopover(detail)
        }
    }

    private var rowAIUsage: some View {
        Button {
            guard !interactionState.consumeSuppressedPrimaryAction() else { return }
            let nextDetail: SystemMetricDetail? = selectedDetail == .ai ? nil : .ai
            selectedDetail = nextDetail
            interactionState.setDetailPopoverPresented(nextDetail != nil)
        } label: {
            HStack(spacing: 8) {
                Text("AI")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                if compactAIProviders.isEmpty {
                    Text("—")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(compactAIProviders) { providerUsage in
                        Text("\(providerUsage.provider.shortLabel) \(providerUsage.value.displayText)")
                            .foregroundStyle(compactAITint(for: providerUsage.value))
                    }
                }
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .frame(minHeight: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(SystemOverlayMetricButtonStyle(interactionState: interactionState))
        .accessibilityLabel("Show AI usage details")
        .accessibilityValue(compactAIAccessibilityValue)
        .popover(isPresented: detailBinding(for: .ai), arrowEdge: .trailing) {
            metricDetailPopover(.ai)
        }
    }

    private var dashboardRowButton: some View {
        Button {
            guard !interactionState.consumeSuppressedPrimaryAction() else { return }
            presentDashboard()
        } label: {
            Label("Dashboard", systemImage: "rectangle.3.group")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(SystemOverlayMetricButtonStyle(interactionState: interactionState))
        .accessibilityLabel("Show system dashboard")
    }

    private func detailBinding(for detail: SystemMetricDetail) -> Binding<Bool> {
        Binding(
            get: { selectedDetail == detail },
            set: { isPresented in
                if !isPresented {
                    selectedDetail = nil
                    interactionState.setDetailPopoverPresented(false)
                }
            }
        )
    }

    @ViewBuilder
    private func metricDetailPopover(_ detail: SystemMetricDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(detail.title, systemImage: detail.systemImage)
                .font(.system(size: 13, weight: .semibold))

            switch detail {
            case .cpu:
                cpuDetail
            case .ram:
                ramDetail
            case .network:
                networkDetail
            case .ssd:
                ssdDetail
            case .ai:
                agentUsage
            }
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
    }

    private var cpuDetail: some View {
        VStack(alignment: .leading, spacing: 9) {
            DetailRow(
                label: "Overall load",
                value: sample?.cpuUsagePercentage.map(NumberFormatting.formatPercentage) ?? "—",
                tint: cpuTint)
            MetricTrendChart(
                title: "CPU, last 60 minutes",
                values: systemMetrics.recentSamples.compactMap(\.cpuUsagePercentage),
                tint: cpuTint
            )
        }
    }

    private var ramDetail: some View {
        VStack(alignment: .leading, spacing: 9) {
            DetailRow(
                label: "Used",
                value: sample?.memory.usagePercentage.map(NumberFormatting.formatPercentage) ?? "—",
                tint: memoryTint)
            DetailRow(label: "Pressure", value: sample?.memory.pressure.label ?? "—", tint: memoryTint)
            DetailRow(
                label: "Swap", value: sample?.memory.swapUsedBytes.map(NumberFormatting.formatBytes) ?? "—")
            MetricTrendChart(
                title: "RAM, last 60 minutes",
                values: systemMetrics.recentSamples.compactMap { $0.memory.usagePercentage },
                tint: memoryTint
            )
        }
    }

    private var networkDetail: some View {
        VStack(alignment: .leading, spacing: 9) {
            DetailRow(
                label: "Download",
                value: NumberFormatting.formatRate(sample?.network.receivedBytesPerSecond), tint: .blue)
            DetailRow(
                label: "Upload", value: NumberFormatting.formatRate(sample?.network.sentBytesPerSecond),
                tint: .blue)
            Text("Rates are measured from active network interfaces every two seconds.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ssdDetail: some View {
        VStack(alignment: .leading, spacing: 9) {
            DetailRow(label: "Free space", value: storageValue, tint: .indigo)
            DetailRow(
                label: "Total capacity",
                value: sample?.storage.totalBytes.map(NumberFormatting.formatBytes) ?? "—")
            Text("Free space on this Mac’s root volume.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            dockerStorageDetail
        }
        .onAppear { dockerStorage.refreshIfNeeded() }
    }

    @ViewBuilder
    private var dockerStorageDetail: some View {
        Group {
            if dockerStorage.isRefreshing && dockerStorage.snapshot == nil {
                dockerStorageLoading
            } else if let snapshot = dockerStorage.snapshot {
                dockerStorageSnapshot(snapshot)
            }
        }
        .id(dockerStoragePresentation)
        .transition(dockerStorageTransition)
        .animation(dockerStorageAnimation, value: dockerStoragePresentation)
    }

    private var dockerStoragePresentation: DockerStoragePresentation {
        if dockerStorage.isRefreshing && dockerStorage.snapshot == nil {
            return .loading
        }
        return dockerStorage.snapshot == nil ? .empty : .snapshot
    }

    private var dockerStorageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    }

    private var dockerStorageAnimation: Animation {
        reduceMotion ? DesignTokens.Animation.reducedFeedback : DesignTokens.Animation.popoverContent
    }

    private var dockerStorageLoading: some View {
        Group {
            Divider()
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Reading Docker storage…")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dockerStorageSnapshot(_ snapshot: DockerStorageSnapshot) -> some View {
        Group {
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Label("Docker storage", systemImage: "shippingbox.fill")
                    .font(.system(size: 10, weight: .semibold))

                ForEach(snapshot.categories) { category in
                    DetailRow(
                        label: category.label,
                        value: NumberFormatting.formatBytes(category.bytes),
                        tint: category.type == "Local Volumes" ? .indigo : .primary
                    )
                }

                if snapshot.volumeCount > 0 {
                    Text("Largest volumes · \(snapshot.volumeCount) total")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(snapshot.largestVolumes) { volume in
                        HStack(spacing: 6) {
                            Text(volume.name)
                                .font(.system(size: 9))
                                .lineLimit(1)
                            Spacer()
                            Text(NumberFormatting.formatBytes(volume.bytes))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var agentUsage: some View {
        if availableAIProviders.isEmpty {
            Text("No provider detected")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        } else {
            ForEach(availableAIProviders, id: \.self) { provider in
                let data = multiService.usageData(for: provider)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        ProviderIconView(provider: provider, size: 13)
                        Text(provider.rawValue).font(.system(size: 10, weight: .medium))
                        Spacer()
                        Text("\(NumberFormatting.formatPercentage(data.remainingPercentage)) left")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.usageTint(for: data.remainingPercentage))
                    }
                    ProgressView(value: min(max(data.remainingPercentage / 100, 0), 1))
                        .tint(Color.usageTint(for: data.remainingPercentage))
                    if let reset = data.resetsAt {
                        Text(resetLabel(for: reset))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AIUsageTrendChart(series: aiUsageHistory)
        }
    }

    private var availableAIProviders: [CLIProvider] {
        multiService.activeProviders.filter { multiService.usageData(for: $0).isAvailable }
    }

    private var aiUsageHistory: [AIUsageHistorySeries] {
        availableAIProviders.map {
            AIUsageHistorySeries(provider: $0, points: multiService.usageHistory(for: $0))
        }
    }

    private var compactNetwork: String {
        guard let network = sample?.network else { return "—" }
        return "↓\(NumberFormatting.formatOverlayRate(network.receivedBytesPerSecond))"
    }

    private var storageValue: String {
        guard let available = sample?.storage.availableBytes else { return "—" }
        return NumberFormatting.formatBytes(available)
    }

    private var cpuTint: Color {
        guard let cpu = sample?.cpuUsagePercentage else { return .secondary }
        return cpu >= 90 ? .red : cpu >= 70 ? .orange : .mint
    }

    private var memoryTint: Color {
        switch sample?.memory.pressure {
        case .critical: return .red
        case .warning: return .orange
        default:
            guard let usage = sample?.memory.usagePercentage else { return .secondary }
            return usage >= 90 ? .red : usage >= 75 ? .orange : .mint
        }
    }

    private func compactAITint(for value: OverlayUsagePresentation.CompactValue) -> Color {
        switch value {
        case let .remainingPercentage(percentage):
            Color.usageTint(for: Double(percentage))
        case .tokenCount:
            .brandAccent
        }
    }

    private var compactAIAccessibilityValue: String {
        guard !compactAIProviders.isEmpty else { return "Unavailable" }
        return compactAIProviders
            .map { "\($0.provider.rawValue) \($0.value.accessibilityText)" }
            .joined(separator: ", ")
    }

    private var overallTint: Color {
        if sample?.memory.pressure == .critical || sample?.thermalState == .critical { return .red }
        if sample?.memory.pressure == .warning || sample?.thermalState == .serious { return .orange }
        if let cpu = sample?.cpuUsagePercentage, cpu >= 90 { return .red }
        if let memory = sample?.memory.usagePercentage, memory >= 90 { return .red }
        if let cpu = sample?.cpuUsagePercentage, cpu >= 70 { return .orange }
        if let memory = sample?.memory.usagePercentage, memory >= 75 { return .orange }
        return .mint
    }

    private var accessibilityValue: String {
        var values = [
            "CPU \(sample?.cpuUsagePercentage.map(NumberFormatting.formatPercentage) ?? "unavailable")",
            "RAM \(sample?.memory.usagePercentage.map(NumberFormatting.formatPercentage) ?? "unavailable")",
            "SSD \(storageValue) free",
        ]
        if !compactAIProviders.isEmpty {
            values.append(compactAIAccessibilityValue)
        }
        return values.joined(separator: ", ")
    }

    private func resetLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return "resets \(formatter.string(from: date))"
    }
}

private struct SystemOverlayMetricButtonStyle: ButtonStyle {
    let interactionState: OverlayInteractionState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isPressing = configuration.isPressed && !interactionState.isDraggingWindow

        configuration.label
            .scaleEffect(isPressing && !reduceMotion ? 0.97 : 1)
            .opacity(isPressing && reduceMotion ? 0.94 : 1)
            .animation(
                reduceMotion ? DesignTokens.Animation.reducedFeedback : DesignTokens.Animation.press,
                value: configuration.isPressed
            )
    }
}

private struct SystemOverlayLifecycleContainer<Content: View>: View {
    let content: Content
    let onSizeChange: ((CGSize) -> Void)?
    let accessibilityValue: String

    var body: some View {
        content
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { onSizeChange?($0) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("System capacity overlay")
            .accessibilityValue(accessibilityValue)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }
}

private struct MetricTrendChart: View {
    let title: String
    let values: [Double]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.04))
                    if values.count >= 3 {
                        trendPath(width: geometry.size.width, height: geometry.size.height)
                            .stroke(tint, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    } else {
                        Text("Collecting history…")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 42)
        }
    }

    private func trendPath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * width
            let y = height - CGFloat(min(max(value, 0), 100) / 100) * height
            index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

extension View {
    fileprivate func systemMonitorSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return
            self
            .background(Color(nsColor: .windowBackgroundColor), in: shape)
            .background(tint, in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8))
            .clipShape(shape)
    }
}
