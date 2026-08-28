import Charts
import SwiftUI

private enum DashboardMetricDetail: String, Identifiable {
    case cpu
    case ram
    case network
    case ssd
    case power
    case thermal
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .ram: "RAM"
        case .network: "Network"
        case .ssd: "SSD"
        case .power: "Power"
        case .thermal: "Thermal"
        case .ai: "AI usage"
        }
    }

    var systemImage: String {
        switch self {
        case .cpu: "cpu"
        case .ram: "memorychip"
        case .network: "arrow.up.arrow.down"
        case .ssd: "internaldrive"
        case .power: "battery.100percent"
        case .thermal: "thermometer.medium"
        case .ai: "wand.and.stars"
        }
    }

    var arrowEdge: Edge {
        switch self {
        case .ram, .power, .thermal:
            .trailing
        default:
            .leading
        }
    }

    var trendTint: Color {
        switch self {
        case .cpu: .mint
        case .ram: .blue
        case .network: .blue
        case .ssd: .indigo
        case .power: .green
        case .thermal: .mint
        case .ai: .brandAccent
        }
    }

    var accessibilityHint: String {
        "Show \(title.lowercased()) details"
    }
}

/// The on-demand panel is the full system dashboard. The floating overlay
/// deliberately stays compact and opens only metric-specific popovers.
struct SystemCapacityDashboardView: View {
    let systemMetrics: SystemMetricsService
    let multiService: MultiProviderUsageService
    let dockerStorage: DockerStorageService
    let onOpenUsage: () -> Void
    let onRefresh: () -> Void

    @State private var selectedMetricDetail: DashboardMetricDetail?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sample: SystemMetricsSample? { systemMetrics.currentSample }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            systemGrid
        }
        .onAppear { systemMetrics.setProcessMonitoringEnabled(true) }
        .onDisappear { systemMetrics.setProcessMonitoringEnabled(false) }
    }

    private var systemGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
            interactiveSystemCard(
                .cpu,
                title: "CPU",
                value: sample?.cpuUsagePercentage.map(NumberFormatting.formatPercentage) ?? "—",
                detail: "overall load",
                icon: "cpu",
                tint: cpuTint
            )
            interactiveSystemCard(
                .ram,
                title: "RAM",
                value: sample?.memory.usagePercentage.map(NumberFormatting.formatPercentage) ?? "—",
                detail: ramDetail,
                icon: "memorychip",
                tint: ramTint
            )
            interactiveSystemCard(
                .network,
                title: "Network",
                value: downloadRate,
                detail: networkDetail,
                icon: "arrow.up.arrow.down",
                tint: .blue
            )
            interactiveSystemCard(
                .ssd,
                title: "SSD",
                value: ssdFreeSpace,
                detail: ssdDetail,
                icon: "internaldrive",
                tint: .indigo
            )
            if let battery = sample?.battery {
                interactiveSystemCard(
                    .power,
                    title: "Power",
                    value: NumberFormatting.formatPercentage(battery.percentage),
                    detail: battery.statusLabel,
                    icon: battery.systemImage,
                    tint: .green
                )
            }
            interactiveSystemCard(
                .thermal,
                title: "Thermal",
                value: sample?.thermalState.label ?? "—",
                detail: "system temperature",
                icon: "thermometer.medium",
                tint: thermalTint
            )
            interactiveSystemCard(
                .ai,
                title: "AI",
                value: aiValue,
                detail: aiDetail,
                icon: "wand.and.stars",
                tint: aiTint
            )
        }
    }

    private func interactiveSystemCard(
        _ metric: DashboardMetricDetail,
        title: String,
        value: String,
        detail: String,
        icon: String,
        tint: Color
    ) -> some View {
        Button {
            selectedMetricDetail = selectedMetricDetail == metric ? nil : metric
        } label: {
            systemCardContent(title, value, detail, icon, tint, isInteractive: true)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(metric.accessibilityHint)
        .accessibilityLabel(metric.accessibilityHint)
        .accessibilityValue(value)
        .popover(isPresented: detailBinding(for: metric), arrowEdge: metric.arrowEdge) {
            metricDetailPopover(metric)
        }
    }

    private func systemCardContent(
        _ title: String,
        _ value: String,
        _ detail: String,
        _ icon: String,
        _ tint: Color,
        isInteractive: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 8, weight: .medium)).foregroundStyle(.tertiary)
                Text(value).font(.system(size: 11, weight: .semibold, design: .rounded)).lineLimit(1)
                Text(detail)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailBinding(for metric: DashboardMetricDetail) -> Binding<Bool> {
        Binding(
            get: { selectedMetricDetail == metric },
            set: { isPresented in
                if !isPresented { selectedMetricDetail = nil }
            }
        )
    }

    @ViewBuilder
    private func metricDetailPopover(_ metric: DashboardMetricDetail) -> some View {
        switch metric {
        case .cpu:
            systemMetricDetailPopover(metric, sort: .cpu)
        case .ram:
            systemMetricDetailPopover(metric, sort: .memory)
        case .network:
            networkDetailPopover
        case .ssd:
            ssdDetailPopover
        case .power:
            powerDetailPopover
        case .thermal:
            thermalDetailPopover
        case .ai:
            aiUsageDetailPopover
        }
    }

    private func systemMetricDetailPopover(
        _ metric: DashboardMetricDetail,
        sort: SystemProcessSort
    ) -> some View {
        let processes = SystemMetricsService.sortedProcesses(systemMetrics.topProcesses, by: sort)

        return VStack(alignment: .leading, spacing: 12) {
            Label("\(metric.title) details", systemImage: metric.systemImage)
                .font(.system(size: 13, weight: .semibold))

            SystemMetricTrendChart(metric: metric, samples: systemMetrics.recentSamples)

            Divider()

            SystemTopProcessesList(processes: processes, sort: sort)
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }

    private var networkDetailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Network details", systemImage: DashboardMetricDetail.network.systemImage)
                .font(.system(size: 13, weight: .semibold))
            DashboardDetailRow(
                label: "Download",
                value: NumberFormatting.formatRate(sample?.network.receivedBytesPerSecond),
                tint: .blue
            )
            DashboardDetailRow(
                label: "Upload",
                value: NumberFormatting.formatRate(sample?.network.sentBytesPerSecond),
                tint: .blue
            )
            Text("Rates use active non-loopback interfaces and update every two seconds.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }

    private var ssdDetailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SSD details", systemImage: DashboardMetricDetail.ssd.systemImage)
                .font(.system(size: 13, weight: .semibold))
            DashboardDetailRow(label: "Free space", value: ssdFreeSpace, tint: .indigo)
            DashboardDetailRow(
                label: "Total capacity",
                value: sample?.storage.totalBytes.map(NumberFormatting.formatBytes) ?? "—"
            )
            Text("Free space on this Mac’s root volume.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            dashboardDockerStorageDetail
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
        .onAppear { dockerStorage.refreshIfNeeded() }
    }

    @ViewBuilder
    private var dashboardDockerStorageDetail: some View {
        if dockerStorage.isRefreshing && dockerStorage.snapshot == nil {
            Divider()
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Reading Docker storage…")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        } else if let snapshot = dockerStorage.snapshot {
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Label("Docker storage", systemImage: "shippingbox.fill")
                    .font(.system(size: 10, weight: .semibold))

                ForEach(snapshot.categories) { category in
                    DashboardDetailRow(
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

    private var powerDetailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Power details", systemImage: DashboardMetricDetail.power.systemImage)
                .font(.system(size: 13, weight: .semibold))
            if let battery = sample?.battery {
                DashboardDetailRow(
                    label: "Charge",
                    value: NumberFormatting.formatPercentage(battery.percentage),
                    tint: .green
                )
                DashboardDetailRow(label: "Status", value: battery.statusLabel, tint: .green)
            } else {
                Text("This Mac does not report a battery.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }

    private var thermalDetailPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Thermal details", systemImage: DashboardMetricDetail.thermal.systemImage)
                .font(.system(size: 13, weight: .semibold))
            DashboardDetailRow(
                label: "System state",
                value: sample?.thermalState.label ?? "—",
                tint: thermalTint
            )
            Text("macOS reports system-wide thermal pressure rather than a hardware temperature.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }

    @ViewBuilder
    private var aiUsageDetailPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Button("Details", action: onOpenUsage)
                    .controlSize(.mini)
                Button(action: onRefresh) {
                    ZStack {
                        Image(systemName: "arrow.clockwise")
                            .opacity(multiService.isLoading ? 0 : 1)
                        ProgressView()
                            .controlSize(.mini)
                            .opacity(multiService.isLoading ? 1 : 0)
                    }
                    .frame(width: 12, height: 12)
                    .animation(refreshFeedbackAnimation, value: multiService.isLoading)
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .disabled(multiService.isLoading)
                .accessibilityLabel(
                    multiService.isLoading ? "Refreshing provider usage" : "Refresh provider usage")
            }
            if availableAIProviders.isEmpty {
                Text(
                    multiService.activeProviders.isEmpty
                        ? "No provider detected" : "No provider usage available"
                )
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            } else {
                ForEach(availableAIProviders, id: \.self) { provider in
                    let data = multiService.usageData(for: provider)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            ProviderIconView(provider: provider, size: 13)
                            Text(provider.rawValue).font(.system(size: 9, weight: .medium))
                            Spacer()
                            Text("\(NumberFormatting.formatPercentage(data.remainingPercentage)) left")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.usageTint(for: data.remainingPercentage))
                            if let reset = data.resetsAt {
                                Text(Self.resetText(for: reset))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ProgressView(value: min(max(data.remainingPercentage / 100, 0), 1))
                            .tint(Color.usageTint(for: data.remainingPercentage))
                    }
                }

                AIUsageTrendChart(series: aiUsageHistory)
            }
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }

    private var aiUsageHistory: [AIUsageHistorySeries] {
        availableAIProviders.map { provider in
            return AIUsageHistorySeries(
                provider: provider,
                points: multiService.usageHistory(for: provider)
            )
        }
    }

    private var refreshFeedbackAnimation: Animation {
        reduceMotion ? DesignTokens.Animation.reducedFeedback : DesignTokens.Animation.popoverContent
    }

    private var availableAIProviders: [CLIProvider] {
        multiService.activeProviders.filter { multiService.usageData(for: $0).isAvailable }
    }

    private var aiUsageData: ProviderUsageData? {
        guard let provider = multiService.criticalProvider else { return nil }
        let data = multiService.usageData(for: provider)
        return data.isAvailable ? data : nil
    }

    private var aiValue: String {
        aiUsageData.map { NumberFormatting.formatPercentage($0.remainingPercentage) } ?? "—"
    }

    private var aiDetail: String {
        aiUsageData.map { "\($0.provider.rawValue) left" } ?? "No provider"
    }

    private var aiTint: Color {
        aiUsageData.map { Color.usageTint(for: $0.remainingPercentage) } ?? .secondary
    }

    private var downloadRate: String {
        NumberFormatting.formatRate(sample?.network.receivedBytesPerSecond)
    }

    private var networkDetail: String {
        "↓\(NumberFormatting.formatRate(sample?.network.receivedBytesPerSecond)) · ↑\(NumberFormatting.formatRate(sample?.network.sentBytesPerSecond))"
    }

    private var ramDetail: String {
        guard let memory = sample?.memory else { return "reading" }
        let swap = memory.swapUsedBytes.map { " · swap \(NumberFormatting.formatBytes($0))" } ?? ""
        return "pressure \(memory.pressure.label.lowercased())\(swap)"
    }

    private var ssdFreeSpace: String {
        sample?.storage.availableBytes.map(NumberFormatting.formatBytes) ?? "—"
    }

    private var ssdDetail: String {
        guard let total = sample?.storage.totalBytes else { return "root volume free space" }
        return "of \(NumberFormatting.formatBytes(total)) total"
    }

    private var cpuTint: Color {
        guard let cpu = sample?.cpuUsagePercentage else { return .secondary }
        return cpu >= 90 ? .red : cpu >= 70 ? .orange : .mint
    }

    private var ramTint: Color {
        switch sample?.memory.pressure {
        case .critical: return .red
        case .warning: return .orange
        default:
            guard let usage = sample?.memory.usagePercentage else { return .secondary }
            return usage >= 90 ? .red : usage >= 75 ? .orange : .mint
        }
    }

    private var thermalTint: Color {
        switch sample?.thermalState {
        case .critical: .red
        case .serious: .orange
        case .fair: .yellow
        default: .mint
        }
    }

    private static func resetText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return "resets \(formatter.string(from: date))"
    }
}

struct AIUsageHistorySeries: Identifiable {
    let provider: CLIProvider
    let points: [UsageHistoryPoint]

    var id: CLIProvider { provider }

    var tint: Color {
        switch provider {
        case .codex: .brandAccent
        case .claudeCode: .orange
        }
    }
}

struct AIUsageTrendChart: View {
    let series: [AIUsageHistorySeries]

    private var hasEnoughHistory: Bool {
        series.contains { $0.points.count >= 2 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label("7-day AI headroom", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                legend
            }

            if hasEnoughHistory {
                Chart {
                    ForEach(series) { item in
                        ForEach(item.points) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Headroom", point.remainingPercentage)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(item.tint)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 48)
                .accessibilityLabel("Seven day AI headroom history")
                .accessibilityValue(accessibilitySummary)
            } else {
                Text("Keep CC-Overlay running to build a private local AI trend.")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .frame(height: 48, alignment: .center)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: 6) {
            ForEach(series) { item in
                HStack(spacing: 3) {
                    Circle()
                        .fill(item.tint)
                        .frame(width: 5, height: 5)
                    Text(item.provider.rawValue)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var accessibilitySummary: String {
        series.compactMap { item in
            guard let latest = item.points.last else { return nil }
            return
                "\(item.provider.rawValue) \(Int(latest.remainingPercentage.rounded())) percent remaining"
        }
        .joined(separator: ", ")
    }
}

private struct SystemMetricTrendChart: View {
    let metric: DashboardMetricDetail
    let samples: [SystemMetricsSample]

    private var values: [Double] {
        switch metric {
        case .cpu:
            samples.compactMap(\.cpuUsagePercentage)
        case .ram:
            samples.compactMap { $0.memory.usagePercentage }
        case .network, .ssd, .power, .thermal, .ai:
            []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Last 60 minutes", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                Text(metric.title)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack {
                    if values.count >= 3 {
                        trendPath(values, width: geometry.size.width, height: geometry.size.height)
                            .stroke(
                                metric.trendTint,
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
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

    private func trendPath(_ values: [Double], width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * width
            let y = height - CGFloat(min(max(value, 0), 100) / 100) * height
            index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

private struct DashboardDetailRow: View {
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

private struct SystemTopProcessesList: View {
    let processes: [SystemProcessMetric]
    let sort: SystemProcessSort

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Top 3 \(sort.label) processes", systemImage: "list.number")
                .font(.system(size: 10, weight: .semibold))

            if processes.isEmpty {
                Text("Reading accessible processes…")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(processes) { process in
                    HStack(spacing: 6) {
                        Text(process.name)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(
                            sort == .cpu
                                ? NumberFormatting.formatCoreUsage(process.cpuUsagePercentage)
                                : NumberFormatting.formatBytes(process.memoryBytes)
                        )
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
