import SwiftUI

struct UsageDecisionView: View {
    let decision: UsageDecision
    var compact = false
    var onTaskSizeChange: ((PlannedTaskSize) -> Void)? = nil
    var onPrimaryAction: (() -> Void)? = nil
    var onFeedback: ((Bool) -> Void)? = nil

    @State private var actionCompleted = false
    @State private var feedbackSelection: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            HStack(alignment: .top, spacing: compact ? 7 : 10) {
                Image(systemName: symbolName)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: compact ? 18 : 24, height: compact ? 18 : 24)
                    .compatGlassCircle(tint: tint.opacity(0.11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(decision.title)
                        .font(.system(size: compact ? 10 : 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !compact {
                        Text(detailText)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 2)

                Text(kindLabel)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }

            if compact {
                Text("\(decision.confidence.label) confidence · \(decision.dataQuality.label)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                evidenceRow
                controlRow
            }
        }
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 5 : 8)
        .compatGlassRoundedRect(
            cornerRadius: compact ? 8 : 10,
            interactive: false,
            tint: tint.opacity(0.08)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Usage recommendation")
        .onChange(of: decision) { _, _ in
            actionCompleted = false
            feedbackSelection = nil
        }
    }

    private var evidenceRow: some View {
        HStack(spacing: 7) {
            Label("\(decision.confidence.label) confidence", systemImage: confidenceSymbol)
            Text("·")
            Text(decision.dataQuality.label)

            if let taskFit = decision.taskFit {
                Text("·")
                Text("\(taskFit.taskSize.label): \(taskFit.label)")
                    .foregroundStyle(taskFit.outcome == .unlikely ? Color.orange : Color.secondary)
            }
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var controlRow: some View {
        HStack(spacing: 6) {
            if let onTaskSizeChange, let taskSize = decision.taskFit?.taskSize {
                Menu {
                    ForEach(PlannedTaskSize.allCases) { size in
                        Button {
                            onTaskSizeChange(size)
                        } label: {
                            if size == taskSize {
                                Label(size.label, systemImage: "checkmark")
                            } else {
                                Text(size.label)
                            }
                        }
                    }
                } label: {
                    Label(taskSize.label, systemImage: "scope")
                }
                .menuStyle(.button)
                .controlSize(.mini)
                .help("Planned task size")
            }

            if let onPrimaryAction, let primaryActionLabel {
                Button {
                    onPrimaryAction()
                    actionCompleted = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        actionCompleted = false
                    }
                } label: {
                    Label(
                        actionCompleted ? completedActionLabel : primaryActionLabel,
                        systemImage: actionCompleted ? "checkmark" : primaryActionSymbol
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }

            Spacer(minLength: 2)

            if let onFeedback {
                Button {
                    guard feedbackSelection == nil else { return }
                    feedbackSelection = true
                    onFeedback(true)
                } label: {
                    Image(systemName: feedbackSelection == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .buttonStyle(.plain)
                .foregroundStyle(feedbackSelection == true ? .mint : .secondary)
                .help("Recommendation was helpful")
                .accessibilityLabel("Recommendation was helpful")
                .disabled(feedbackSelection != nil)

                Button {
                    guard feedbackSelection == nil else { return }
                    feedbackSelection = false
                    onFeedback(false)
                } label: {
                    Image(systemName: feedbackSelection == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                }
                .buttonStyle(.plain)
                .foregroundStyle(feedbackSelection == false ? .orange : .secondary)
                .help("Recommendation was not helpful")
                .accessibilityLabel("Recommendation was not helpful")
                .disabled(feedbackSelection != nil)
            }
        }
        .font(.system(size: 9, weight: .medium))
    }

    private var detailText: String {
        guard decision.kind == .wait, let resetAt = decision.resetAt else {
            return decision.detail
        }
        let remaining = max(resetAt.timeIntervalSinceNow, 0)
        return "\(decision.detail) Next reset in \(DurationFormatting.compactReset(remaining))."
    }

    private var kindLabel: String {
        switch decision.kind {
        case .run: return "RUN"
        case .switchProvider: return "SWITCH"
        case .useReset: return "FULL RESET"
        case .wait: return "WAIT"
        case .refresh: return "REFRESH"
        case .setup: return "SETUP"
        }
    }

    private var primaryActionLabel: String? {
        switch decision.kind {
        case .run, .switchProvider:
            guard let provider = decision.recommendedProvider else { return nil }
            return "Copy \(provider.launchCommand)"
        case .useReset:
            return "Open Codex Usage"
        case .wait:
            return decision.resetAt == nil ? nil : "Notify at reset"
        case .refresh:
            return "Refresh now"
        case .setup:
            return "Open settings"
        }
    }

    private var completedActionLabel: String {
        switch decision.kind {
        case .run, .switchProvider: return "Command copied"
        case .useReset: return "Usage opened"
        case .wait: return "Reminder set"
        case .refresh: return "Refreshing"
        case .setup: return "Opened"
        }
    }

    private var primaryActionSymbol: String {
        switch decision.kind {
        case .run, .switchProvider: return "doc.on.doc"
        case .useReset: return "arrow.counterclockwise.circle"
        case .wait: return "bell"
        case .refresh: return "arrow.clockwise"
        case .setup: return "gearshape"
        }
    }

    private var confidenceSymbol: String {
        switch decision.confidence {
        case .high: return "checkmark.shield.fill"
        case .medium: return "shield.lefthalf.filled"
        case .low: return "exclamationmark.shield"
        }
    }

    private var symbolName: String {
        switch decision.kind {
        case .run: return "play.fill"
        case .switchProvider: return "arrow.left.arrow.right"
        case .useReset: return "arrow.counterclockwise.circle.fill"
        case .wait: return "clock.fill"
        case .refresh: return "arrow.clockwise"
        case .setup: return "terminal"
        }
    }

    private var tint: Color {
        switch decision.kind {
        case .run: return .mint
        case .switchProvider: return .blue
        case .useReset: return .purple
        case .wait: return .orange
        case .refresh: return .orange
        case .setup: return .secondary
        }
    }
}
