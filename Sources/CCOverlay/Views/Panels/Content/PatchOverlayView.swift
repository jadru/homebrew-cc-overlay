import SwiftUI

/// Current usage affects the companion's mood. New developer tokens observed
/// after launch grow its workshop and evolution; treats grow care cosmetics.
struct PatchOverlayView: View {
    let multiService: MultiProviderUsageService
    @Bindable var settings: AppSettings
    let progress: PatchProgressStore
    let interactionState: OverlayInteractionState

    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @State private var pointerResponse = PatchInteraction.still
    @State private var lastPointerLocation: CGPoint?
    @State private var treatReaction = CompanionTreatReaction.idle
    @State private var treatBurst: TreatCollectionResult?
    @State private var treatDismissTask: Task<Void, Never>?
    @State private var treatReactionTask: Task<Void, Never>?
    @State private var feedBurstID: Int?
    @State private var feedDismissTask: Task<Void, Never>?
    @State private var feedReaction = CompanionFeedReaction.idle
    @State private var feedReactionTask: Task<Void, Never>?
    @State private var evolutionBurst: CompanionEvolution?
    @State private var evolutionDismissTask: Task<Void, Never>?
    @State private var careBurst: CompanionCare?
    @State private var careDismissTask: Task<Void, Never>?
    @State private var focusDayBurst = false
    @State private var focusDayDismissTask: Task<Void, Never>?

    private var presentation: PatchPresentation {
        PatchPresentation.assess(
            providerData: multiService.availableProviders.map(multiService.usageData(for:)),
            staleAfter: multiService.staleThreshold
        )
    }

    var body: some View {
        let current = presentation

        TimelineView(.periodic(from: .now, by: PatchMotion.frameInterval)) { timeline in
            let motion = reducesMotion ? PatchMotion.still : PatchMotion.frame(at: timeline.date)
            let sprite = PatchSprite.forMood(current.mood, frameIndex: motion.frameIndex)

            ZStack {
                PatchOverlayBackground(style: settings.companionBackground)

                PatchWorkshopImage(workshop: progress.growth.workshop, size: PatchInteraction.overlaySize.width)
                    .offset(y: PatchInteraction.workshopVerticalOffset)

                if let pet = progress.currentPet {
                    CompanionContactShadow(
                        interaction: pointerResponse,
                        motion: motion,
                        isDimmed: current.mood == .offline
                    )
                    .offset(y: PatchInteraction.companionShadowVerticalOffset)
                    .allowsHitTesting(false)

                    CompanionEvolutionAura(evolution: progress.growth.evolution)
                        .offset(y: 3)
                        .allowsHitTesting(false)

                    Button(action: collectTreat) {
                        CompanionPetImage(
                            pet: pet,
                            width: PatchInteraction.companionWidth,
                            patchSprite: sprite,
                            careAccessory: progress.careAccessory,
                            bodyParallax: pointerResponse.bodyParallax
                        )
                            .opacity(current.companionOpacity)
                            .saturation(current.companionSaturation)
                            .scaleEffect(
                                current.companionScale
                                    * pointerResponse.scale
                                    * motion.scale
                                    * (careBurst == nil ? 1 : 1.06)
                            )
                            .scaleEffect(
                                x: treatReaction.horizontalScale * feedReaction.horizontalScale,
                                y: treatReaction.verticalScale * feedReaction.verticalScale,
                                anchor: .bottom
                            )
                            .rotationEffect(
                                .degrees(
                                    pointerResponse.rotationDegrees
                                        + motion.rotationDegrees
                                        + treatReaction.rotationDegrees
                                        + feedReaction.rotationDegrees
                                )
                            )
                            .offset(
                                x: pointerResponse.offset.width,
                                y: PatchInteraction.companionVerticalOffset
                                    + pointerResponse.offset.height
                                    + motion.verticalOffset
                                    + treatReaction.verticalOffset
                                    + feedReaction.verticalOffset
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Click for one treat · drag anywhere to move \(pet.name)")
                    .accessibilityLabel("\(pet.name), your coding companion")
                    .accessibilityHint("Click to collect one companion treat when ready. Drag anywhere to move the companion.")
                } else {
                    CompanionOverlayDrawButton(progress: progress, interactionState: interactionState)
                        .offset(y: 20)
                }

                if let feedBurstID {
                    CompanionFeedAnimation(reducesMotion: reducesMotion)
                        .id(feedBurstID)
                        .allowsHitTesting(false)
                }

                if let treatBurst {
                    CompanionTreatCollectionAnimation(
                        totalTreats: treatBurst.totalTreats,
                        reducesMotion: reducesMotion
                    )
                    // A fresh identity restarts @State phase for every click.
                    .id(treatBurst.totalTreats)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }

                if let evolutionBurst {
                    CompanionEvolutionBurst(evolution: evolutionBurst)
                        .transition(.opacity.combined(with: .scale(scale: 0.84)))
                        .offset(y: -88)
                        .allowsHitTesting(false)
                }

                if let careBurst {
                    CompanionCareBurst(care: careBurst)
                        .transition(.opacity.combined(with: .scale(scale: 0.84)))
                        .offset(y: -88)
                        .allowsHitTesting(false)
                }

                if focusDayBurst {
                    CompanionFocusDayBurst(streak: progress.currentFocusStreak)
                        .transition(.opacity.combined(with: .scale(scale: 0.84)))
                        .offset(y: -112)
                        .allowsHitTesting(false)
                }

                CompanionOverlayHUD(
                    presentation: current,
                    progress: progress,
                    onFeed: feedOneTreat
                )
                    .offset(y: PatchInteraction.hudVerticalOffset)
            }
            .frame(width: PatchInteraction.overlaySize.width, height: PatchInteraction.overlaySize.height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    lastPointerLocation = location
                    withAnimation(reducesMotion ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: 0.16)) {
                        pointerResponse = reducesMotion ? .still : PatchInteraction.pointerResponse(at: location)
                    }
                case .ended:
                    lastPointerLocation = nil
                    withAnimation(reducesMotion ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: 0.2)) {
                        pointerResponse = .still
                    }
                }
            }
        }
        .frame(width: PatchInteraction.overlaySize.width, height: PatchInteraction.overlaySize.height)
        .accessibilityElement(children: .contain)
        .accessibilityValue(accessibilityValue(for: presentation))
        .help("Click your companion for treats. Drag anywhere to move it. Hover the usage badge for the next reset.")
        .onChange(of: progress.growth.evolution) { oldEvolution, newEvolution in
            guard newEvolution > oldEvolution else { return }
            showEvolution(newEvolution)
        }
        .onChange(of: progress.focusDayCount) { oldCount, newCount in
            guard newCount > oldCount else { return }
            showFocusDay()
        }
        .onChange(of: progress.totalFeeds) { oldCount, newCount in
            guard newCount > oldCount, progress.currentPet != nil else { return }
            showCare(progress.currentCare)
        }
        .onDisappear {
            treatDismissTask?.cancel()
            treatReactionTask?.cancel()
            feedDismissTask?.cancel()
            feedReactionTask?.cancel()
            evolutionDismissTask?.cancel()
            careDismissTask?.cancel()
            focusDayDismissTask?.cancel()
        }
    }

    private func collectTreat() {
        guard !interactionState.consumeSuppressedPrimaryAction() else { return }
        guard let result = progress.collectTreat() else { return }
        withAnimation(reducesMotion ? nil : .easeOut(duration: 0.12)) {
            treatBurst = result
        }
        playTreatReaction()

        treatDismissTask?.cancel()
        treatDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }
            withAnimation(reducesMotion ? nil : .easeOut(duration: 0.18)) {
                treatBurst = nil
            }
        }
    }

    private func playTreatReaction() {
        guard !reducesMotion else { return }
        treatReactionTask?.cancel()
        withAnimation(.easeOut(duration: 0.09)) {
            treatReaction = .crouch
        }
        treatReactionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.22)) {
                treatReaction = .launch
            }
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                treatReaction = .settle
            }
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                treatReaction = .idle
            }
        }
    }

    private func feedOneTreat() {
        guard !interactionState.consumeSuppressedPrimaryAction() else { return }
        guard let feed = progress.feedCurrentCompanion() else { return }

        feedBurstID = feed.totalFeeds
        playFeedReaction()

        feedDismissTask?.cancel()
        feedDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(760))
            guard !Task.isCancelled else { return }
            feedBurstID = nil
        }
    }

    private func playFeedReaction() {
        guard !reducesMotion else { return }

        feedReactionTask?.cancel()
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.1)) {
            feedReaction = .notice
        }
        feedReactionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.14)) {
                feedReaction = .nibble
            }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.16)) {
                feedReaction = .pleased
            }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.18)) {
                feedReaction = .idle
            }
        }
    }

    private func accessibilityValue(for presentation: PatchPresentation) -> String {
        let headroom = presentation.headroomPercentage.map { "\(Int($0.rounded())) percent headroom" } ?? "usage unavailable"
        let pet = progress.currentPet.map { "\($0.name), \($0.species)" } ?? "no companion adopted"
        return "\(pet), \(presentation.title), \(headroom), \(progress.growth.evolution.title), care \(progress.currentCare.title), \(progress.growthTokens) developer tokens, \(progress.treats) companion treats. Drag anywhere to move the companion."
    }

    private func showEvolution(_ evolution: CompanionEvolution) {
        withAnimation(reducesMotion ? nil : .spring(response: 0.32, dampingFraction: 0.7)) {
            evolutionBurst = evolution
        }
        evolutionDismissTask?.cancel()
        evolutionDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(reducesMotion ? nil : .easeOut(duration: 0.2)) {
                evolutionBurst = nil
            }
        }
    }

    private func showCare(_ care: CompanionCare) {
        withAnimation(reducesMotion ? nil : .spring(response: 0.28, dampingFraction: 0.68)) {
            careBurst = care
        }
        careDismissTask?.cancel()
        careDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(reducesMotion ? nil : .easeOut(duration: 0.18)) {
                careBurst = nil
            }
        }
    }

    private func showFocusDay() {
        withAnimation(reducesMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
            focusDayBurst = true
        }
        focusDayDismissTask?.cancel()
        focusDayDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(reducesMotion ? nil : .easeOut(duration: 0.2)) {
                focusDayBurst = false
            }
        }
    }
}

private struct CompanionOverlayHUD: View {
    let presentation: PatchPresentation
    let progress: PatchProgressStore
    let onFeed: () -> Void

    var body: some View {
        CompanionUsageHUD(
            presentation: presentation,
            treats: progress.treats,
            feedCost: PatchProgressStore.feedTreatCost,
            canFeed: progress.currentPet != nil && progress.treats >= PatchProgressStore.feedTreatCost,
            maximumWidth: PatchInteraction.hudMaximumWidth,
            feedOneServing: onFeed
        )
    }
}

private struct PatchOverlayBackground: View {
    let style: CompanionBackground

    var body: some View {
        Group {
            switch style {
            case .transparent:
                Color.clear
            case .opaque:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.09, green: 0.13, blue: 0.21))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.11), lineWidth: 1)
                    }
            }
        }
    }
}

private struct CompanionOverlayDrawButton: View {
    let progress: PatchProgressStore
    let interactionState: OverlayInteractionState
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @State private var result: CompanionDrawResult?

    var body: some View {
        Button {
            guard !interactionState.consumeSuppressedPrimaryAction() else { return }
            guard let draw = progress.drawCompanion() else { return }
            withAnimation(reducesMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84)) {
                result = draw
            }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: result == nil ? "questionmark.diamond.fill" : "sparkles")
                    .font(.system(size: 28, weight: .medium))
                Text(result.map { "Meet \($0.pet.name)" } ?? "Draw your companion")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text(progress.adoptionTickets > 0 ? "Use a token-earned ticket · no duplicates" : "Earn developer tokens for a ticket")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 146, height: 116)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.orange.opacity(0.42), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!progress.canAdoptCompanion)
        .accessibilityLabel("Draw your first companion")
    }

}

/// A two-row, hard-edged contact shadow grounds the pet without introducing
/// blur. It reacts more slowly than the pet and its foreground accessory,
/// which makes the transparent overlay read as a small depth scene.
private struct CompanionContactShadow: View {
    let interaction: PatchInteraction
    let motion: PatchMotion
    let isDimmed: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black)
                .frame(width: 78, height: 3)
            Rectangle()
                .fill(.black)
                .frame(width: 56, height: 3)
                .offset(y: -3)
        }
        .frame(width: 84, height: 12)
        .scaleEffect(
            x: interaction.contactShadowScale * idleShadowScale,
            y: 1,
            anchor: .center
        )
        .opacity(isDimmed ? 0.08 : interaction.contactShadowOpacity)
        .offset(x: interaction.contactShadowOffset.width, y: interaction.contactShadowOffset.height)
        .accessibilityHidden(true)
    }

    private var idleShadowScale: CGFloat {
        1 - CGFloat(max(-motion.verticalOffset, 0)) * 0.018
    }
}

private struct CompanionEvolutionAura: View {
    let evolution: CompanionEvolution

    var body: some View {
        ZStack {
            switch evolution {
            case .rookie:
                EmptyView()
            case .calibrated:
                pixelSparkle(x: -67, y: -37, size: 5, color: .yellow)
                pixelSparkle(x: 64, y: -23, size: 4, color: .mint)
            case .evolved:
                pixelSparkle(x: -68, y: -39, size: 6, color: .yellow)
                pixelSparkle(x: 64, y: -25, size: 5, color: .mint)
                pixelSparkle(x: -54, y: 35, size: 4, color: .orange)
                pixelSparkle(x: 54, y: 34, size: 4, color: .purple)
            case .legendary:
                Circle()
                    .stroke(Color.orange.opacity(0.52), lineWidth: 2)
                    .frame(width: 144, height: 114)
                pixelSparkle(x: -68, y: -39, size: 6, color: .yellow)
                pixelSparkle(x: 64, y: -25, size: 5, color: .mint)
                pixelSparkle(x: -54, y: 35, size: 5, color: .orange)
                pixelSparkle(x: 54, y: 34, size: 5, color: .purple)
            }
        }
        .frame(width: 152, height: 122)
        .accessibilityHidden(true)
    }

    private func pixelSparkle(x: CGFloat, y: CGFloat, size: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.7), radius: 4)
            .offset(x: x, y: y)
    }
}

private struct CompanionEvolutionBurst: View {
    let evolution: CompanionEvolution

    var body: some View {
        Label("Evolution · \(evolution.title)", systemImage: "sparkles")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(Color.orange.opacity(0.46), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
            .accessibilityLabel("Companion evolved to \(evolution.title)")
    }
}

private struct CompanionCareBurst: View {
    let care: CompanionCare

    var body: some View {
        Label(label, systemImage: care.equippedAccessory == nil ? "heart.fill" : "tshirt.fill")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(Color.orange.opacity(0.46), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
            .accessibilityLabel(label)
    }

    private var label: String {
        if let accessory = care.equippedAccessory {
            return "\(care.title) · \(accessory.title)"
        }
        if let remaining = care.feedsUntilNextAccessory {
            return "Care +1 · \(remaining) to next look"
        }
        return "Care · \(care.title)"
    }
}

private struct CompanionFocusDayBurst: View {
    let streak: Int

    var body: some View {
        Label("Focus day complete · \(streak)-day streak", systemImage: "flame.fill")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(Color.orange.opacity(0.46), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
            .accessibilityLabel("Focus day complete. \(streak) day streak")
    }
}

private struct CompanionTreatCollectionAnimation: View {
    let totalTreats: Int
    let reducesMotion: Bool
    @State private var phase = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            CompanionTreatSprite()
                .scaleEffect(treatScale)
                .rotationEffect(.degrees(phase == 1 ? 180 : 0))
                .offset(treatOffset)
                .opacity(phase >= 2 ? 0 : 1)

            Text("+1")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .shadow(color: .orange.opacity(0.85), radius: 0, x: 1, y: 1)
                .offset(x: 2, y: phase == 0 ? -38 : -78)
                .opacity(phase >= 2 ? 0 : 1)

            if phase >= 2 {
                CompanionTreatSprite()
                    .scaleEffect(reducesMotion ? 1.08 : 1.35)
                    .opacity(0.35)
                    .offset(x: 32, y: PatchInteraction.hudRewardTargetY)
            }
        }
        .onAppear {
            animationTask = Task { @MainActor in
                guard !reducesMotion else {
                    phase = 2
                    return
                }
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.22)) {
                    phase = 1
                }
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.14)) {
                    phase = 2
                }
            }
        }
        .onDisappear { animationTask?.cancel() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("One companion treat collected. \(totalTreats) total treats")
    }

    private var treatOffset: CGSize {
        return switch phase {
        case 0:
            CGSize(width: 18, height: PatchInteraction.companionRewardOriginY)
        case 1:
            CGSize(width: 25, height: -66)
        default:
            CGSize(width: 32, height: PatchInteraction.hudRewardTargetY)
        }
    }

    private var treatScale: CGFloat {
        switch phase {
        case 0: 0.66
        case 1: 1.06
        default: 0.48
        }
    }
}

/// Reverses the collection path: a snack rises from the HUD to the companion,
/// then resolves into a few crisp crumbs and a care heart. It deliberately
/// uses a single short arc rather than a particle flood.
private struct CompanionFeedAnimation: View {
    let reducesMotion: Bool

    @State private var phase = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            CompanionTreatSprite()
                .scaleEffect(phase == 0 ? 0.7 : 1)
                .rotationEffect(.degrees(phase == 1 ? -92 : 0))
                .offset(treatOffset)
                .opacity(phase >= 2 ? 0 : 1)

            feedResult
                .scaleEffect(phase >= 2 ? 1 : 0.72)
                .opacity(phase >= 2 ? 1 : 0)
                .offset(x: -2, y: -5)
        }
        .onAppear {
            animationTask = Task { @MainActor in
                guard !reducesMotion else {
                    phase = 2
                    return
                }
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.22)) {
                    phase = 1
                }
                try? await Task.sleep(for: .milliseconds(230))
                guard !Task.isCancelled else { return }
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.13)) {
                    phase = 2
                }
            }
        }
        .onDisappear { animationTask?.cancel() }
        .accessibilityHidden(true)
    }

    private var treatOffset: CGSize {
        switch phase {
        case 0:
            CGSize(width: 32, height: PatchInteraction.hudRewardTargetY)
        case 1:
            CGSize(width: -1, height: PatchInteraction.companionRewardOriginY)
        default:
            CGSize(width: -1, height: PatchInteraction.companionRewardOriginY)
        }
    }

    private var feedResult: some View {
        ZStack {
            PixelHeartSprite()
                .offset(x: -10, y: -11)

            PixelTreatCrumb()
                .offset(x: -16, y: 4)
            PixelTreatCrumb()
                .offset(x: 11, y: 1)
            PixelTreatCrumb()
                .offset(x: 3, y: 11)
        }
    }
}

private struct CompanionTreatSprite: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0.27, green: 0.11, blue: 0.02))
                .frame(width: 16, height: 10)
                .offset(y: 1)
            Rectangle()
                .fill(Color(red: 0.72, green: 0.30, blue: 0.05))
                .frame(width: 12, height: 8)
                .offset(x: 2, y: 2)
            Rectangle()
                .fill(Color(red: 0.96, green: 0.52, blue: 0.10))
                .frame(width: 6, height: 3)
                .offset(x: 3, y: 3)
            Rectangle()
                .fill(Color(red: 1, green: 0.81, blue: 0.28))
                .frame(width: 3, height: 3)
                .offset(x: 10, y: 4)
        }
        .frame(width: 16, height: 12)
        .shadow(color: .orange.opacity(0.42), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

private struct PixelTreatCrumb: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.27, green: 0.11, blue: 0.02))
                .frame(width: 4, height: 4)
            Rectangle()
                .fill(Color(red: 0.96, green: 0.52, blue: 0.10))
                .frame(width: 2, height: 2)
        }
        .accessibilityHidden(true)
    }
}

private struct PixelHeartSprite: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0.45, green: 0.08, blue: 0.13))
                .frame(width: 4, height: 4)
                .offset(x: 2, y: 1)
            Rectangle()
                .fill(Color(red: 0.94, green: 0.25, blue: 0.34))
                .frame(width: 4, height: 4)
                .offset(x: 10, y: 1)
            Rectangle()
                .fill(Color(red: 0.45, green: 0.08, blue: 0.13))
                .frame(width: 16, height: 7)
                .offset(y: 4)
            Rectangle()
                .fill(Color(red: 0.45, green: 0.08, blue: 0.13))
                .frame(width: 12, height: 4)
                .offset(x: 2, y: 10)
            Rectangle()
                .fill(Color(red: 0.45, green: 0.08, blue: 0.13))
                .frame(width: 8, height: 2)
                .offset(x: 4, y: 14)
            Rectangle()
                .fill(Color(red: 0.94, green: 0.25, blue: 0.34))
                .frame(width: 12, height: 6)
                .offset(x: 2, y: 4)
            Rectangle()
                .fill(Color(red: 0.94, green: 0.25, blue: 0.34))
                .frame(width: 8, height: 4)
                .offset(x: 4, y: 10)
            Rectangle()
                .fill(Color(red: 1, green: 0.62, blue: 0.64))
                .frame(width: 2, height: 3)
                .offset(x: 4, y: 4)
        }
        .frame(width: 16, height: 16)
        .shadow(color: Color.red.opacity(0.28), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}
