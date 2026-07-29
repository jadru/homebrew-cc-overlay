import SwiftUI

struct RunOutcomeView: View {
    let run: PendingRun
    let onOutcome: (RunOutcome) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.mint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(run.projectName ?? "\(run.provider.rawValue) run")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    Text("Started \(elapsedText(now: context.date)) ago · mark the outcome when done")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                Button("Finished") {
                    onOutcome(.completed)
                }
                .controlSize(.mini)
                .buttonStyle(.bordered)

                Menu {
                    ForEach(RunOutcome.allCases.filter { $0 != .completed }) { outcome in
                        Button(outcome.label) {
                            onOutcome(outcome)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .controlSize(.mini)
                .accessibilityLabel("Choose another run outcome")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .compatGlassRoundedRect(cornerRadius: 9, interactive: false, tint: Color.mint.opacity(0.06))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run outcome")
    }

    private func elapsedText(now: Date) -> String {
        DurationFormatting.compactReset(max(0, now.timeIntervalSince(run.startedAt)))
    }
}
