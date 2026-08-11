import SwiftUI

/// Persistent workshop, evolution, and crews grow from developer tokens
/// observed after launch. Overlay clicks collect treats for companion care.
struct PatchProgressCard: View {
    let progress: PatchProgressStore

    private var growth: CompanionGrowth { progress.growth }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Companion workshop").font(.system(size: 12, weight: .semibold))
                    Text("Level \(growth.level) · \(growth.title)")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(NumberFormatting.formatTokenCount(progress.growthTokens))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    Text("DEV TOKENS")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.orange)
                .accessibilityLabel("\(progress.growthTokens) developer tokens")
            }

            if let next = growth.nextLevelTokenCount {
                ProgressView(value: growth.progressToNextLevel)
                    .tint(.orange)
                    .accessibilityLabel("Companion token progress")
                    .accessibilityValue("\(progress.growthTokens) of \(next) developer tokens")
                Text("\(NumberFormatting.formatTokenCount(progress.growthTokens)) / \(NumberFormatting.formatTokenCount(next)) · +\(NumberFormatting.formatTokenCount(progress.sessionGrowthTokens)) this launch")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            } else {
                Label("Your companion has reached studio icon", systemImage: "pawprint.fill")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
            }

            Label("Evolution · \(growth.evolution.title)", systemImage: "sparkles")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.orange)

            FocusDayProgress(progress: progress)

            VStack(alignment: .leading, spacing: 5) {
                Text("Permanent gear · \(progress.unlockedGear.count)/\(PatchGear.allCases.count)")
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                Text("Tokens unlock tickets and progress. Treats grow each companion and unlock its care cosmetics.")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 5) {
                    ForEach(PatchGear.allCases) { gear in
                        PatchGearRow(gear: gear, isUnlocked: progress.unlockedGear.contains(gear))
                    }
                }
            }

            CompanionCollectionCard(progress: progress)
        }
        .padding(11)
        .compatGlassRoundedRect(cornerRadius: 14, interactive: false, tint: Color.orange.opacity(0.05))
        .accessibilityElement(children: .contain)
    }
}

private struct FocusDayProgress: View {
    let progress: PatchProgressStore

    private var currentValue: Double {
        min(Double(progress.todayFocusTokens) / Double(PatchProgressStore.dailyFocusTokenTarget), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Focus streak · \(progress.currentFocusStreak) day\(progress.currentFocusStreak == 1 ? "" : "s")", systemImage: "flame.fill")
                Spacer()
                Text("\(NumberFormatting.formatTokenCount(progress.todayFocusTokens)) / \(NumberFormatting.formatTokenCount(PatchProgressStore.dailyFocusTokenTarget))")
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.orange)

            ProgressView(value: currentValue)
                .tint(.orange)
                .accessibilityLabel("Today’s focus day progress")
                .accessibilityValue("\(progress.todayFocusTokens) of \(PatchProgressStore.dailyFocusTokenTarget) tokens")

            Text("A focus day needs \(NumberFormatting.formatTokenCount(PatchProgressStore.dailyFocusTokenTarget)) observed developer tokens.")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct PatchGearRow: View {
    let gear: PatchGear
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 5) {
            if isUnlocked {
                PatchGearImage(gear: gear, size: 20)
            } else {
                Image(systemName: "lock.fill").font(.system(size: 9, weight: .medium)).frame(width: 20, height: 20)
            }
            Text(gear.title).lineLimit(1)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(isUnlocked ? .primary : .tertiary)
        .help(isUnlocked ? gear.detail : "Unlocks at \(NumberFormatting.formatTokenCount(gear.unlockTokenCount)) developer tokens")
        .accessibilityLabel(gear.title)
        .accessibilityValue(isUnlocked ? "Unlocked" : "Locked")
    }
}
