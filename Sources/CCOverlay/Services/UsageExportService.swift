import AppKit
import Foundation
import UniformTypeIdentifiers

enum UsageExportService {

    // MARK: - Markdown Summary

    static func markdownSummary(
        data: ProviderUsageData,
        projects: [ProjectCostSummary]? = nil
    ) -> String {
        var lines: [String] = []
        lines.append("## CC-Overlay Usage Summary")
        lines.append("**Provider**: \(data.provider.rawValue)")

        if let plan = data.planName {
            lines.append("**Plan**: \(plan)")
        }

        lines.append("**\(data.primaryWindowLabel) Window**: \(Int(data.usedPercentage))% used")

        if let cost = data.estimatedCost {
            lines.append("**Estimated Cost**: \(NumberFormatting.formatDollarCost(cost.windowCost)) (\(cost.windowLabel)) / \(NumberFormatting.formatDollarCost(cost.dailyCost)) (\(cost.dailyLabel))")
        }

        if let tokens = data.tokenBreakdown {
            lines.append("")
            lines.append("### Token Breakdown (\(tokens.title))")
            lines.append("- Input: \(NumberFormatting.formatTokenCount(tokens.usage.inputTokens))")
            lines.append("- Output: \(NumberFormatting.formatTokenCount(tokens.usage.outputTokens))")
            lines.append("- Cache Write: \(NumberFormatting.formatTokenCount(tokens.usage.cacheCreationInputTokens))")
            lines.append("- Cache Read: \(NumberFormatting.formatTokenCount(tokens.usage.cacheReadInputTokens))")
        }

        if let projects, !projects.isEmpty {
            lines.append("")
            lines.append("### Projects")
            for project in projects {
                lines.append("- \(project.projectName): \(NumberFormatting.formatDollarCost(project.cost.totalCost)) (\(project.sessionCount) sessions)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - CSV Export

    static func csvExport(entries: [ParsedUsageEntry]) -> String {
        var lines: [String] = []
        lines.append("timestamp,session_id,project,model,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            let ts = formatter.string(from: entry.timestamp)
            let project = entry.projectName ?? ""
            lines.append("\(ts),\(entry.sessionId),\(project),\(entry.model),\(entry.inputTokens),\(entry.outputTokens),\(entry.cacheCreationTokens),\(entry.cacheReadTokens)")
        }

        return lines.joined(separator: "\n")
    }

    static func csvExport(snapshots: [UsageSnapshot]) -> String {
        var lines: [String] = []
        lines.append("timestamp,provider,interval_type,project,session_id,model,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens,total_cost")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        for snapshot in snapshots.sorted(by: { $0.timestamp < $1.timestamp }) {
            let ts = formatter.string(from: snapshot.timestamp)
            let totalCost = String(format: "%.6f", snapshot.totalCost)
            let provider = snapshot.provider.replacingOccurrences(of: "\"", with: "'")
            let interval = snapshot.intervalType.replacingOccurrences(of: "\"", with: "'")
            let project = snapshot.projectName?.replacingOccurrences(of: "\"", with: "'") ?? ""
            let sessionId = ""
            let model = ""

            lines.append(
                "\(ts),\(provider),\(interval),\(project),\(sessionId),\(model),\(snapshot.inputTokens),\(snapshot.outputTokens),\(snapshot.cacheCreationTokens),\(snapshot.cacheReadTokens),\(totalCost)"
            )
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Clipboard

    @MainActor
    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - File Save

    @MainActor
    static func saveCSVFile(_ csv: String) async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]

        let dateString = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        panel.nameFieldStringValue = "cc-overlay-usage-\(dateString).csv"

        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return }

        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
