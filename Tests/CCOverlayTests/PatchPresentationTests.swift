import XCTest
@testable import CCOverlay

final class PatchPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    func testThrivesWhenHeadroomIsHighAndPaceIsSustainable() {
        let presentation = PatchPresentation.assess(
            providerData: [usage(headroom: 80, resetOffset: 4 * 60 * 60)], now: now
        )

        XCTAssertEqual(presentation.mood, .thriving)
        XCTAssertEqual(presentation.pace, .onPace)
        XCTAssertEqual(presentation.headroomPercentage, 80)
    }

    func testFastBurnStaysFocusedEvenWithHighHeadroom() {
        let presentation = PatchPresentation.assess(
            providerData: [usage(headroom: 80, resetOffset: 5 * 60 * 60)], now: now
        )

        XCTAssertEqual(presentation.mood, .focused)
        XCTAssertEqual(presentation.pace, .burningFast)
        XCTAssertEqual(presentation.detail, "You have room, but usage is burning faster than the reset pace.")
    }

    func testLowHeadroomMakesPatchRest() {
        let presentation = PatchPresentation.assess(
            providerData: [usage(headroom: 5, resetOffset: 4 * 60 * 60)], now: now
        )
        XCTAssertEqual(presentation.mood, .resting)
        XCTAssertEqual(presentation.headroomPercentage, 5)
    }

    func testUnavailableUsageLeavesPatchOffline() {
        let presentation = PatchPresentation.assess(providerData: [], now: now)
        XCTAssertEqual(presentation.mood, .offline)
        XCTAssertNil(presentation.headroomPercentage)
        XCTAssertEqual(presentation.pace, .unavailable)
    }

    func testPatchMotionAdvancesOncePerSecondAndLoops() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        XCTAssertEqual(PatchMotion.frame(at: start).frameIndex, 0)
        XCTAssertEqual(PatchMotion.frame(at: start.addingTimeInterval(1)).frameIndex, 1)
        XCTAssertEqual(PatchMotion.frame(at: start.addingTimeInterval(2)).frameIndex, 2)
        XCTAssertEqual(PatchMotion.frame(at: start.addingTimeInterval(3)).frameIndex, 3)
        XCTAssertEqual(PatchMotion.frame(at: start), PatchMotion.frame(at: start.addingTimeInterval(4)))
    }

    func testPointerResponseIsCenteredAtRestAndMovesTowardPointer() {
        let centered = PatchInteraction.pointerResponse(at: PatchInteraction.center)
        XCTAssertEqual(centered.offset.width, 0, accuracy: 0.001)
        XCTAssertEqual(centered.offset.height, 0, accuracy: 0.001)
        XCTAssertEqual(centered.rotationDegrees, 0, accuracy: 0.001)

        let right = PatchInteraction.pointerResponse(
            at: CGPoint(x: PatchInteraction.overlaySize.width, y: 0)
        )
        XCTAssertGreaterThan(right.offset.width, 0)
        XCTAssertLessThan(right.offset.height, 0)
        XCTAssertGreaterThan(right.rotationDegrees, 0)
        XCTAssertGreaterThan(right.contactShadowOffset.width, right.bodyParallax.width)
        XCTAssertLessThan(right.contactShadowScale, 1)
    }

    func testOverlayReservesASeparateHUDLaneBelowTheCompanionScene() {
        let centerY = PatchInteraction.overlaySize.height / 2
        let companionBottom = centerY
            + PatchInteraction.companionVerticalOffset
            + PatchInteraction.companionWidth * 0.53
        let workshopTop = centerY
            + PatchInteraction.workshopVerticalOffset
            - PatchInteraction.overlaySize.width / 2
            + PatchInteraction.overlaySize.width * (432 / 627.0)
        let workshopBottom = centerY
            + PatchInteraction.workshopVerticalOffset
            - PatchInteraction.overlaySize.width / 2
            + PatchInteraction.overlaySize.width * (535 / 627.0)
        let hudTop = centerY + PatchInteraction.hudVerticalOffset - 15

        // The floor tucks directly under the feet; a tiny overlap is fine for
        // the tallest sprite, but a separate empty lane is not.
        XCTAssertGreaterThanOrEqual(workshopTop - companionBottom, -8)
        XCTAssertLessThanOrEqual(workshopTop - companionBottom, 2)
        XCTAssertGreaterThanOrEqual(hudTop - workshopBottom, 2)
        XCTAssertLessThan(PatchInteraction.hudMaximumWidth, PatchInteraction.overlaySize.width)
    }

    func testPatchBackgroundHasTransparentAndOpaqueChoices() {
        XCTAssertEqual(CompanionBackground.allCases, [.transparent, .opaque])
        XCTAssertEqual(CompanionBackground.transparent.label, "Transparent")
        XCTAssertEqual(CompanionBackground.opaque.label, "Opaque")
    }

    func testSpritesFollowMoodAndOneSecondFrame() {
        XCTAssertEqual(PatchSprite.forMood(.resting, frameIndex: 0), .sleep)
        XCTAssertEqual(PatchSprite.forMood(.focused, frameIndex: 1), .wag)
        XCTAssertEqual(PatchSprite.forMood(.thriving, frameIndex: 1), .celebrate)
    }

    func testTreatReactionHasAPreparationAndLaunchWithoutSpriteChanges() {
        XCTAssertGreaterThan(CompanionTreatReaction.crouch.verticalOffset, 0)
        XCTAssertLessThan(CompanionTreatReaction.launch.verticalOffset, 0)
        XCTAssertLessThan(CompanionTreatReaction.crouch.verticalScale, 1)
        XCTAssertGreaterThan(CompanionTreatReaction.launch.verticalScale, 1)
        XCTAssertNotEqual(CompanionTreatReaction.launch.rotationDegrees, 0)
    }

    func testFeedReactionUsesANoticeBiteAndPleasedTransformSequence() {
        XCTAssertLessThan(CompanionFeedReaction.notice.verticalOffset, 0)
        XCTAssertGreaterThan(CompanionFeedReaction.nibble.verticalOffset, 0)
        XCTAssertLessThan(CompanionFeedReaction.nibble.verticalScale, 1)
        XCTAssertGreaterThan(CompanionFeedReaction.pleased.verticalScale, 1)
        XCTAssertNotEqual(CompanionFeedReaction.nibble.rotationDegrees, 0)
    }

    private func usage(headroom: Double, resetOffset: TimeInterval) -> ProviderUsageData {
        ProviderUsageData(
            provider: .codex,
            isAvailable: true,
            usedPercentage: 100 - headroom,
            remainingPercentage: headroom,
            primaryWindowLabel: "5h",
            resetsAt: now.addingTimeInterval(resetOffset),
            rateLimitBuckets: [RateBucket(label: "5h", utilization: 100 - headroom, resetsAt: now.addingTimeInterval(resetOffset))],
            lastRefresh: now
        )
    }
}
