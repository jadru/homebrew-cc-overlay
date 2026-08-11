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
