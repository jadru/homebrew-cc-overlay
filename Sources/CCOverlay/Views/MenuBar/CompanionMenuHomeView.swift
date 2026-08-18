import SwiftUI

/// The menu's default screen is a compact status board, not a second settings
/// window. Detailed usage, collection, and configuration open only when the
/// user asks for them.
struct CompanionMenuHomeView: View {
    enum UsageFreshness {
        case live
        case estimated
        case stale
        case failed

        var label: String {
            switch self {
            case .live: "Live"
            case .estimated: "Estimated"
            case .stale: "Stale"
            case .failed: "Needs refresh"
            }
        }

        var symbolName: String {
            switch self {
            case .live: "checkmark.circle.fill"
            case .estimated: "wand.and.stars"
            case .stale: "clock.fill"
            case .failed: "arrow.clockwise"
            }
        }

        var tint: Color {
            switch self {
            case .live: .mint
            case .estimated, .stale: .orange
            case .failed: .red
            }
        }

        var needsRefresh: Bool {
            switch self {
            case .live, .estimated: false
            case .stale, .failed: true
            }
        }
    }

    let presentation: PatchPresentation
    let provider: ProviderUsageData
    let progress: PatchProgressStore
    var onOpenUsage: () -> Void
    var onOpenCollection: () -> Void
    var onRefreshUsage: () -> Void
    let usageFreshness: UsageFreshness

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var latestFeed: CompanionFeedResult?
    @State private var feedFeedbackTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            companionSummary
            Divider()
            nextStep
            Divider()
            usageSummary
        }
        .padding(.vertical, 4)
        .animation(celebrationAnimation, value: latestFeed?.totalFeeds)
        .onDisappear { feedFeedbackTask?.cancel() }
    }

    private var usageSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Usage", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(provider.provider.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Label(usageFreshness.label, systemImage: usageFreshness.symbolName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(usageFreshness.tint)
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(headroomLabel)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Text(usageFreshness.needsRefresh ? "Refresh before relying on this value" : "Resets \(resetLabel)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(usageFreshness.needsRefresh ? "Refresh" : "Details") {
                    usageFreshness.needsRefresh ? onRefreshUsage() : onOpenUsage()
                }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint(
                        usageFreshness.needsRefresh
                            ? "Fetches the latest usage from the provider"
                            : "Opens detailed usage and provider information"
                    )
            }

            ProgressView(value: min(max(provider.remainingPercentage / 100, 0), 1))
                .tint(headroomTint)
                .accessibilityLabel("Usage headroom")
                .accessibilityValue(usageFreshness.needsRefresh ? "Last reported \(NumberFormatting.formatPercentage(provider.remainingPercentage))" : "\(NumberFormatting.formatPercentage(provider.remainingPercentage)) remaining")
        }
    }

    @ViewBuilder
    private var companionSummary: some View {
        if let pet = progress.currentPet {
            HStack(alignment: .center, spacing: 10) {
                CompanionPetImage(
                    pet: pet,
                    width: 52,
                    patchSprite: PatchSprite.forMood(presentation.mood, frameIndex: 0),
                    careAccessory: progress.careAccessory
                )
                .frame(width: 58, height: 58)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(pet.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text("\(pet.species) · \(progress.currentCare.title)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Label("\(progress.treats) treats", systemImage: "carrot.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: feedCompanion) {
                    Label("Feed · \(PatchProgressStore.feedTreatCost)", systemImage: "carrot.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
                .disabled(progress.treats < PatchProgressStore.feedTreatCost)
                .help(feedHelp)
                .accessibilityLabel(feedHelp)
            }

            if let latestFeed {
                Label(feedResultLabel(latestFeed, pet: pet), systemImage: "heart.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .transition(feedbackTransition)
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: 58, height: 58)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Your first companion")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("A duplicate-free ticket unlocks after observed developer tokens.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Collection", action: onOpenCollection)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var nextStep: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Label(progress.adoptionTickets > 0 ? "Companion ticket" : "Next companion ticket", systemImage: "ticket.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(ticketStatusLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(progress.adoptionTickets > 0 ? .green : .secondary)
            }

            ProgressView(value: ticketProgressValue)
                .tint(.orange)
                .accessibilityLabel("Progress to next companion ticket")
                .accessibilityValue(ticketStatusLabel)

            HStack(alignment: .center, spacing: 8) {
                Text(ticketDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button(progress.adoptionTickets > 0 ? "Draw" : "Usage") {
                    progress.adoptionTickets > 0 ? onOpenCollection() : onOpenUsage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(progress.adoptionTickets > 0 ? .orange : nil)
            }
        }
    }

    private var ticketProgressValue: Double {
        guard progress.adoptionTickets == 0 else { return 1 }
        let remainder = progress.growthTokens % PatchProgressStore.adoptionTicketTokenCost
        return Double(remainder) / Double(PatchProgressStore.adoptionTicketTokenCost)
    }

    private var ticketStatusLabel: String {
        if progress.adoptionTickets > 0 {
            return "\(progress.adoptionTickets) ready"
        }
        return "\(NumberFormatting.formatTokenCount(progress.growthTokens % PatchProgressStore.adoptionTicketTokenCost)) / \(NumberFormatting.formatTokenCount(PatchProgressStore.adoptionTicketTokenCost))"
    }

    private var ticketDescription: String {
        if progress.adoptionTickets > 0 {
            return "Your ticket draws one unadopted companion at random."
        }
        let remaining = max(progress.nextAdoptionTicketTokenCount - progress.growthTokens, 0)
        return "\(NumberFormatting.formatTokenCount(remaining)) more observed developer tokens unlocks a draw."
    }

    private var resetLabel: String {
        guard let reset = provider.resetsAt else { return "not reported" }
        return reset.formatted(.relative(presentation: .named))
    }

    private var headroomLabel: String {
        let percentage = NumberFormatting.formatPercentage(provider.remainingPercentage)
        return usageFreshness.needsRefresh ? "\(percentage) reported" : "\(percentage) left"
    }

    private var headroomTint: Color {
        usageFreshness.needsRefresh ? .secondary : Color.usageTint(for: provider.remainingPercentage)
    }

    private var feedHelp: String {
        if progress.treats >= PatchProgressStore.feedTreatCost {
            return "Feed one meal for \(PatchProgressStore.feedTreatCost) treats. \(progress.treats) treats available."
        }
        return "Need \(PatchProgressStore.feedTreatCost) treats to feed. \(progress.treats) available."
    }

    private var celebrationAnimation: Animation? {
        reduceMotion ? DesignTokens.Animation.reducedFeedback : DesignTokens.Animation.companionCelebration
    }

    private var feedbackTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private func feedCompanion() {
        guard let result = progress.feedCurrentCompanion() else { return }
        withAnimation(celebrationAnimation) {
            latestFeed = result
        }
        scheduleFeedFeedbackDismissal(for: result)
    }

    private func scheduleFeedFeedbackDismissal(for result: CompanionFeedResult) {
        feedFeedbackTask?.cancel()
        feedFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled, latestFeed?.totalFeeds == result.totalFeeds else { return }
            withAnimation(reduceMotion ? DesignTokens.Animation.reducedFeedback : DesignTokens.Animation.companionDismiss) {
                latestFeed = nil
            }
        }
    }

    private func feedResultLabel(_ result: CompanionFeedResult, pet: CompanionPet) -> String {
        if let accessory = result.newlyUnlockedAccessories.last {
            return "\(pet.name) unlocked \(accessory.title)."
        }
        return "\(pet.name) enjoyed a meal · \(result.companionFeedCount) meals"
    }
}
