import SwiftUI

/// Patch's live, usage-derived state. Permanent workshop progress stays in the
/// separate card below, so current spend can never make an item look earned.
struct PatchCompanionCard: View {
    let presentation: PatchPresentation
    let progress: PatchProgressStore
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Group {
                    if let pet = progress.currentPet {
                        CompanionPetImage(
                            pet: pet,
                            width: 42,
                            patchSprite: .forMood(presentation.mood, frameIndex: 0),
                            careAccessory: progress.careAccessory
                        )
                    } else {
                        Image(systemName: "questionmark.diamond.fill")
                            .foregroundStyle(.orange)
                    }
                }
                    .frame(width: 42, height: 42)
                    .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.currentPet.map { "\($0.name)'s live signal" } ?? "Draw your companion")
                        .font(.system(size: 12, weight: .semibold))
                    Label(presentation.title, systemImage: presentation.symbolName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(statusTint)
                }

                Spacer(minLength: 8)

                Toggle("Show companion", isOn: $settings.showOverlay)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .accessibilityLabel("Show companion overlay")
            }

            HStack(spacing: 8) {
                metric(
                    title: "Headroom",
                    value: presentation.headroomPercentage.map { "\(Int($0.rounded()))% left" } ?? "Waiting",
                    symbol: "gauge.with.dots.needle.50percent"
                )
                metric(title: "Next reset", value: resetLabel, symbol: "arrow.counterclockwise")
            }

            Text(presentation.detail)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .compatGlassRoundedRect(cornerRadius: 14, interactive: false, tint: Color.orange.opacity(0.06))
        .accessibilityElement(children: .contain)
    }

    private var resetLabel: String {
        guard let resetAt = presentation.resetAt else { return "Not reported" }
        return resetAt.formatted(.relative(presentation: .named))
    }

    private var statusTint: Color {
        switch presentation.mood {
        case .offline: .secondary
        case .resting: .orange
        case .watchful: .yellow
        case .focused: .mint
        case .thriving: .green
        }
    }

    private func metric(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 8, weight: .medium)).foregroundStyle(.tertiary)
                Text(value).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
