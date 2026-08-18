import XCTest
@testable import CCOverlay

final class OverlayInteractionTests: XCTestCase {
    func testPointerDownSuppressesHoverExpansion() {
        XCTAssertFalse(
            OverlayInteractionPolicy.shouldExpand(
                isHovered: true,
                isPointerDown: true,
                alwaysExpanded: false
            )
        )
    }

    func testSettledHoverExpandsOverlay() {
        XCTAssertTrue(
            OverlayInteractionPolicy.shouldExpand(
                isHovered: true,
                isPointerDown: false,
                alwaysExpanded: false
            )
        )
    }

    func testAlwaysExpandedOverridesPointerDown() {
        XCTAssertTrue(
            OverlayInteractionPolicy.shouldExpand(
                isHovered: true,
                isPointerDown: true,
                alwaysExpanded: true
            )
        )
    }

    func testPointerJitterDoesNotStartWindowDrag() {
        XCTAssertFalse(
            OverlayInteractionPolicy.shouldBeginWindowDrag(deltaX: 6, deltaY: 6)
        )
        XCTAssertFalse(
            OverlayInteractionPolicy.shouldBeginWindowDrag(deltaX: 9.9, deltaY: 0)
        )
    }

    func testClearPointerMovementStartsWindowDrag() {
        XCTAssertTrue(
            OverlayInteractionPolicy.shouldBeginWindowDrag(deltaX: 10, deltaY: 0)
        )
        XCTAssertTrue(
            OverlayInteractionPolicy.shouldBeginWindowDrag(deltaX: 8, deltaY: 6)
        )
    }

    func testAlwaysVisibleCompanionCanPresentWithoutUsageData() {
        XCTAssertTrue(
            OverlayVisibilityPolicy.canPresent(
                presentation: .companion,
                hasAvailableProviders: false,
                companionAlwaysVisible: true
            )
        )
        XCTAssertFalse(
            OverlayVisibilityPolicy.canPresent(
                presentation: .usagePill,
                hasAvailableProviders: false,
                companionAlwaysVisible: true
            )
        )
    }

    func testAlwaysVisibleCompanionStaysUpForNonDeveloperApps() {
        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldShowForActiveApplication(
                presentation: .companion,
                companionAlwaysVisible: true,
                isSelfApplication: false,
                isWhitelistedDeveloperTool: false
            )
        )
        XCTAssertFalse(
            OverlayVisibilityPolicy.shouldShowForActiveApplication(
                presentation: .companion,
                companionAlwaysVisible: false,
                isSelfApplication: false,
                isWhitelistedDeveloperTool: false
            )
        )
    }

    @MainActor
    func testSecondInstanceCannotClaimTheSharedOverlayLock() {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-overlay-instance-\(UUID().uuidString).lock")
        defer { try? FileManager.default.removeItem(at: lockURL) }

        let firstInstance = SingleInstanceCoordinator(lockURL: lockURL)
        let secondInstance = SingleInstanceCoordinator(lockURL: lockURL)

        XCTAssertTrue(firstInstance.claimOrActivateExisting(isUpdateHandoff: false))
        XCTAssertFalse(secondInstance.claimOrActivateExisting(isUpdateHandoff: false))

        firstInstance.release()
        XCTAssertTrue(secondInstance.claimOrActivateExisting(isUpdateHandoff: false))
        secondInstance.release()
    }

    @MainActor
    func testWindowDragSuppressesOnlyTheCurrentPrimaryAction() {
        let state = OverlayInteractionState()

        state.beginPointerSequence()
        state.beginWindowDrag()
        state.endPointerSequence()

        XCTAssertTrue(state.consumeSuppressedPrimaryAction())
        XCTAssertFalse(state.consumeSuppressedPrimaryAction())

        state.beginPointerSequence()
        XCTAssertFalse(state.consumeSuppressedPrimaryAction())
    }
}
