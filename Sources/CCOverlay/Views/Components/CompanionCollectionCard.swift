import SwiftUI

/// The Collection sheet is where a ticket becomes a teammate and an owned
/// teammate becomes active. Token rules stay beside usage; care rewards stay
/// in the rewards section below the roster.
struct CompanionCollectionCard: View {
    let progress: PatchProgressStore
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var latestDraw: CompanionDrawResult?
    @State private var latestFeed: CompanionFeedResult?
    @State private var previewPet: CompanionPet?
    @State private var isDrawing = false
    @State private var drawTask: Task<Void, Never>?
    @State private var feedFeedbackTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 14) {
            companionSummary

            if let latestDraw {
                feedback(
                    "\(latestDraw.pet.name) joined your crew.",
                    symbol: "sparkles"
                )
            }

            if let latestFeed, let pet = progress.currentPet {
                feedback(feedResultLabel(latestFeed, pet: pet), symbol: "heart.fill")
            }

            if !compact {
                Divider()
                collection
            }
        }
        .padding(compact ? 9 : 0)
        .animation(celebrationAnimation, value: latestDraw?.pet)
        .onDisappear {
            drawTask?.cancel()
            feedFeedbackTask?.cancel()
        }
    }

    @ViewBuilder
    private var companionSummary: some View {
        if let pet = displayedPet {
            HStack(alignment: .center, spacing: compact ? 9 : 12) {
                CompanionPetImage(pet: pet, width: compact ? 38 : 58)
                    .frame(width: compact ? 40 : 62, height: compact ? 40 : 62)
                    .background(
                        Color.orange.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: compact ? 11 : 15, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text("Active companion")
                        .font(.system(size: compact ? 8 : 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(pet.name)
                        .font(.system(size: compact ? 13 : 17, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text("\(pet.species) · \(progress.currentCare.title)")
                        .font(.system(size: compact ? 8 : 10, weight: .medium))
                        .foregroundStyle(.orange)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Label("\(progress.treats)", systemImage: "carrot.fill")
                            .foregroundStyle(.orange)
                        Text("·")
                        Text(careNextStep)
                    }
                    .font(.system(size: compact ? 8 : 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { feedCompanion(servingCount: 1) }) {
                    Label("Feed · \(PatchProgressStore.feedTreatCost)", systemImage: "carrot.fill")
                        .font(.system(size: compact ? 9 : 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(compact ? .mini : .small)
                .tint(.orange)
                .disabled(isDrawing || progress.treats < PatchProgressStore.feedTreatCost)
                .help(feedHelp)
                .accessibilityLabel(feedHelp)
            }
        } else {
            HStack(alignment: .center, spacing: compact ? 9 : 12) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: compact ? 18 : 24, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: compact ? 40 : 62, height: compact ? 40 : 62)
                    .background(
                        Color.orange.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: compact ? 11 : 15, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text("First companion")
                        .font(.system(size: compact ? 13 : 17, weight: .bold, design: .rounded))
                    Text(firstCompanionDescription)
                        .font(.system(size: compact ? 8 : 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if progress.canAdoptCompanion {
                    Button("Draw") { drawCompanion() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(compact ? .mini : .small)
                        .tint(.orange)
                        .disabled(isDrawing)
                }
            }
        }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your crew")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(progress.ownedPets.count) of \(CompanionPet.allCases.count) companions adopted")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if progress.canAdoptCompanion {
                    Button(action: drawCompanion) {
                        Label("Use ticket", systemImage: "ticket.fill")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.orange)
                    .disabled(isDrawing)
                    .accessibilityLabel("Use an adoption ticket to draw a new companion")
                } else {
                    Label(crewStatus, systemImage: crewStatusSymbol)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4),
                spacing: 7
            ) {
                ForEach(CompanionPet.allCases) { pet in
                    CompanionRosterCell(
                        pet: pet,
                        isOwned: progress.ownedPets.contains(pet),
                        isUnlocked: progress.unlockedPets.contains(pet),
                        isSelected: progress.currentPet == pet,
                        select: {
                            withAnimation(reduceMotion ? nil : DesignTokens.Animation.selection) {
                                progress.selectCompanion(pet)
                            }
                        }
                    )
                }
            }
            .accessibilityLabel("Companion collection")
        }
    }

    private func feedback(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: compact ? 8 : 10, weight: .medium))
            .foregroundStyle(.orange)
            .transition(feedbackTransition)
    }

    private var celebrationAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.84)
    }

    private var feedbackTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95))
    }

    private var displayedPet: CompanionPet? {
        isDrawing ? previewPet : progress.currentPet
    }

    private var careNextStep: String {
        let care = progress.currentCare
        guard let next = care.nextAccessory else {
            return "Every care reward is unlocked."
        }
        return "Next care reward: \(next.title) in \(next.unlockFeedCount - care.feedCount) meals"
    }

    private var feedHelp: String {
        if progress.treats >= PatchProgressStore.feedTreatCost {
            return "Feed one meal for \(PatchProgressStore.feedTreatCost) treats. \(progress.treats) treats available."
        }
        return "Need \(PatchProgressStore.feedTreatCost) treats to feed. \(progress.treats) available."
    }

    private var firstCompanionDescription: String {
        if progress.canAdoptCompanion {
            return "A ticket is ready. Draw a random teammate."
        }
        return "Developer tokens earn the next ticket in Usage."
    }

    private var crewStatus: String {
        if progress.availablePets.isEmpty, progress.unlockedPets.count == CompanionPet.allCases.count {
            return "Collection complete"
        }
        if progress.availablePets.isEmpty {
            return "More crews ahead"
        }
        return "Next ticket in Usage"
    }

    private var crewStatusSymbol: String {
        progress.availablePets.isEmpty ? "checkmark.circle" : "bolt.fill"
    }

    private func drawCompanion() {
        guard !isDrawing, progress.canAdoptCompanion else { return }
        let candidates = progress.availablePets
        isDrawing = true
        latestDraw = nil

        drawTask?.cancel()
        if reduceMotion {
            finishDraw()
            return
        }
        drawTask = Task { @MainActor in
            for frame in 0..<10 {
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.06)) {
                    previewPet = candidates[frame % candidates.count]
                }
                try? await Task.sleep(for: .milliseconds(70))
            }

            guard !Task.isCancelled else { return }
            finishDraw()
        }
    }

    private func finishDraw() {
        guard let result = progress.drawCompanion() else {
            isDrawing = false
            return
        }
        withAnimation(celebrationAnimation) {
            previewPet = result.pet
            latestDraw = result
            isDrawing = false
        }
    }

    private func feedCompanion(servingCount: Int) {
        guard let result = progress.feedCurrentCompanion(servingCount: servingCount) else { return }
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
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
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

/// Developer-token progress lives beside the source usage that creates it,
/// never beside the treat-based care action in Collection.
struct CompanionAdoptionProgressView: View {
    let progress: PatchProgressStore
    var onOpenCollection: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Label(progress.adoptionTickets > 0 ? "Companion ticket" : "Next companion ticket", systemImage: "ticket.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(progress.adoptionTickets > 0 ? "\(progress.adoptionTickets) ready" : ticketProgressLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(progress.adoptionTickets > 0 ? .green : .secondary)
            }

            ProgressView(value: ticketProgressValue)
                .tint(.orange)
                .accessibilityLabel("Progress to next adoption ticket")
                .accessibilityValue(ticketAccessibilityValue)

            Text(ticketDescription)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if progress.adoptionTickets > 0, let onOpenCollection {
                Button(action: onOpenCollection) {
                    Label("Open collection", systemImage: "pawprint.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
                .accessibilityHint("Opens Collection to use this ticket")
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var ticketProgressValue: Double {
        guard progress.adoptionTickets == 0 else { return 1 }
        let cost = PatchProgressStore.adoptionTicketTokenCost
        let remainder = progress.growthTokens % cost
        return Double(remainder) / Double(cost)
    }

    private var ticketProgressLabel: String {
        "\(NumberFormatting.formatTokenCount(progress.growthTokens % PatchProgressStore.adoptionTicketTokenCost)) / \(NumberFormatting.formatTokenCount(PatchProgressStore.adoptionTicketTokenCost))"
    }

    private var ticketDescription: String {
        if progress.adoptionTickets > 0 {
            return "A duplicate-free draw is ready in Collection. Every unadopted companion is equally likely."
        }
        let remaining = max(progress.nextAdoptionTicketTokenCount - progress.growthTokens, 0)
        return "\(NumberFormatting.formatTokenCount(remaining)) more developer tokens earns a ticket."
    }

    private var ticketAccessibilityValue: String {
        if progress.adoptionTickets > 0 {
            return "\(progress.adoptionTickets) adoption ticket ready"
        }
        return "\(ticketProgressLabel) developer tokens toward the next ticket"
    }
}

private struct CompanionRosterCell: View {
    let pet: CompanionPet
    let isOwned: Bool
    let isUnlocked: Bool
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 2) {
                CompanionPetImage(pet: pet, width: 34)
                    .frame(height: 38)
                    .opacity(isOwned ? 1 : (isUnlocked ? 0.46 : 0.2))
                    .overlay(alignment: .bottomTrailing) {
                        statusBadge
                    }

                Text(pet.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isOwned ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.vertical, 5)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.orange.opacity(0.7) : Color.primary.opacity(0.07), lineWidth: isSelected ? 1.5 : 0.5)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isOwned)
        .help(rosterHelp)
        .accessibilityLabel("\(pet.name), \(pet.species)")
        .accessibilityValue(rosterValue)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.orange)
        } else if !isUnlocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(3)
                .background(.thinMaterial, in: Circle())
        } else if !isOwned {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.orange)
                .padding(3)
                .background(.thinMaterial, in: Circle())
        }
    }

    private var background: Color {
        if isSelected { return Color.orange.opacity(0.11) }
        if isOwned { return Color.primary.opacity(0.035) }
        return Color.primary.opacity(0.02)
    }

    private var rosterHelp: String {
        if isOwned { return "Use \(pet.name), the \(pet.species)" }
        if isUnlocked { return "Available from a future adoption ticket" }
        return "Unlocks with \(pet.crew.unlockDescription)"
    }

    private var rosterValue: String {
        if isSelected { return "Current companion" }
        if isOwned { return "Adopted" }
        return isUnlocked ? "Available from a ticket" : "Locked"
    }
}
