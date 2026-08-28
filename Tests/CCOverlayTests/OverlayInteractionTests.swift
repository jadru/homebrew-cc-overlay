import XCTest
@testable import CCOverlay

final class OverlayInteractionTests: XCTestCase {
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

    func testSystemOverlayCanPresentWithoutProviderUsage() {
        XCTAssertTrue(
            OverlayVisibilityPolicy.canPresent(
                visibilityMode: .always
            )
        )
        XCTAssertTrue(
            OverlayVisibilityPolicy.canPresent(
                visibilityMode: .developerToolsOnly
            )
        )
    }

    func testVisibilityModesRespectActiveApplication() {
        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldShowForActiveApplication(
                visibilityMode: .always,
                isSelfApplication: false,
                isWhitelistedDeveloperTool: false
            )
        )
        XCTAssertTrue(
            OverlayVisibilityPolicy.shouldShowForActiveApplication(
                visibilityMode: .developerToolsOnly,
                isSelfApplication: false,
                isWhitelistedDeveloperTool: true
            )
        )
        XCTAssertFalse(
            OverlayVisibilityPolicy.shouldShowForActiveApplication(
                visibilityMode: .developerToolsOnly,
                isSelfApplication: false,
                isWhitelistedDeveloperTool: false
            )
        )
    }

    func testOverlayFrameKeepsItsOriginalMonitorDuringTheFirstSizeChange() {
        let primary = NSRect(x: 0, y: 77, width: 1920, height: 973)
        let secondary = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let initialOverlayFrame = NSRect(x: 1698, y: 1010, width: 222, height: 40)

        XCTAssertEqual(
            OverlayScreenPolicy.visibleFrame(
                for: initialOverlayFrame,
                availableScreenFrames: [primary, secondary],
                fallback: primary
            ),
            primary
        )
    }

    func testUserPositionedResizePreservesDroppedOrigin() {
        let resized = OverlayResizePlacementPolicy.resizedFrame(
            from: NSRect(x: 800, y: 500, width: 220, height: 40),
            to: CGSize(width: 280, height: 40),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_920, height: 1_080),
            preservesTrailingEdge: false
        )

        XCTAssertEqual(resized.origin, NSPoint(x: 800, y: 500))
        XCTAssertEqual(resized.size, CGSize(width: 280, height: 40))
    }

    func testInitialResizeKeepsOverlayAnchoredToTrailingEdge() {
        let resized = OverlayResizePlacementPolicy.resizedFrame(
            from: NSRect(x: 1_700, y: 1_000, width: 220, height: 40),
            to: CGSize(width: 280, height: 40),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_920, height: 1_080),
            preservesTrailingEdge: true
        )

        XCTAssertEqual(resized.maxX, 1_920)
        XCTAssertEqual(resized.maxY, 1_040)
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

    @MainActor
    func testClickSuppressionRemainsArmedUntilTheDraggedMetricHandlesMouseUp() {
        let state = OverlayInteractionState()

        state.beginPointerSequence()
        state.beginWindowDrag()

        // `MovableOverlayPanel` sends mouse-up to the button before ending the
        // pointer sequence, so the detail action can consume this flag.
        XCTAssertTrue(state.consumeSuppressedPrimaryAction())
        state.endPointerSequence()
        XCTAssertFalse(state.consumeSuppressedPrimaryAction())
    }

    @MainActor
    func testExternalClickDismissesOnlyAnOpenDetailPopover() {
        let state = OverlayInteractionState()

        state.dismissDetailPopoverForExternalClick()
        XCTAssertEqual(state.detailDismissalGeneration, 0)

        state.setDetailPopoverPresented(true)
        state.dismissDetailPopoverForExternalClick()
        XCTAssertEqual(state.detailDismissalGeneration, 1)

        state.dismissDetailPopoverForExternalClick()
        XCTAssertEqual(state.detailDismissalGeneration, 1)
    }

    func testOverlayContextMenuUsesExplicitDashboardHideAndQuitLabels() {
        XCTAssertEqual(OverlayContextMenuAction.showOverlay.title, "Show Overlay")
        XCTAssertEqual(OverlayContextMenuAction.showDashboard.title, "Show Dashboard")
        XCTAssertEqual(OverlayContextMenuAction.hideOverlay.title, "Hide Overlay")
        XCTAssertEqual(OverlayContextMenuAction.quitApplication.title, "Quit CC-Overlay")
    }
}
