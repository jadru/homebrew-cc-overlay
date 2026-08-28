# 001 — Smooth the Docker storage result replacement

- **Status**: TODO
- **Commit**: c7f27d6
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 2 source files, about 35 lines

## Problem

The SSD popover makes a rare asynchronous content swap. While Docker storage is
loading, it shows one small row; when the snapshot arrives, that row is
replaced immediately by the Docker category and volume list. The popover's
content and intrinsic height therefore change without a state transition.

```swift
// Sources/CCOverlay/Views/Panels/Content/SystemOverlayView.swift:214-256 — current
@ViewBuilder
private var dockerStorageDetail: some View {
    if dockerStorage.isRefreshing && dockerStorage.snapshot == nil {
        Divider()
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text("Reading Docker storage…")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    } else if let snapshot = dockerStorage.snapshot {
        Divider()
        VStack(alignment: .leading, spacing: 7) {
            Label("Docker storage", systemImage: "shippingbox.fill")
            // categories and largest volumes
        }
    }
}
```

This is a rare, state-explanatory transition. It is unlike the compact overlay
metrics, which refresh every two seconds and must remain immediate.

## Target

Use an opacity-only transition for Reduce Motion. Otherwise, enter the new
Docker content with opacity plus a very small `scale(0.98 -> 1)` from the top.
Use an `easeOut` animation of exactly **0.18 seconds**. The transition must
not animate the panel frame, width, height, padding, or drag position.

```swift
// Target transition policy
private var popoverContentTransition: AnyTransition {
    reduceMotion
        ? .opacity
        : .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
}

// Target animation token
static let popoverContent = SwiftUI.Animation.easeOut(duration: 0.18)
```

Wrap the loading/snapshot branches in a `Group`, assign a stable identity for
`empty`, `loading`, and `snapshot`, and apply the transition and animation to
that group. The `empty` state must still render no Docker section when Docker
is unavailable.

## Repo conventions to follow

- Shared SwiftUI motion values live in
  `Sources/CCOverlay/Extensions/DesignTokens.swift:27-31`.
- The existing update banner is the transition exemplar:
  `Sources/CCOverlay/Extensions/DesignTokens.swift:35-45` branches to opacity
  under `accessibilityReduceMotion` and otherwise combines opacity with
  `scale(0.98, anchor: .top)`.
- The overlay's drag settlement deliberately calls
  `setFrame(..., animate: false)` in
  `Sources/CCOverlay/Services/OverlayManager.swift:180-186`. Preserve that
  behavior; this plan is only for the popover's content state.

## Steps

1. In `Sources/CCOverlay/Extensions/DesignTokens.swift`, add
   `DesignTokens.Animation.popoverContent` with the exact value
   `SwiftUI.Animation.easeOut(duration: 0.18)`. Do not change `press`,
   `selection`, `reveal`, or `reducedFeedback`.
2. In `Sources/CCOverlay/Views/Panels/Content/SystemOverlayView.swift`, add
   `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to
   `SystemOverlayView`.
3. In that view, add a private `DockerStoragePresentation` identity or an
   equivalent private computed identity with exactly these states:
   `empty` when there is no snapshot and no initial refresh, `loading` when
   `dockerStorage.isRefreshing && dockerStorage.snapshot == nil`, and
   `snapshot` when `dockerStorage.snapshot != nil`.
4. Add a private transition helper that returns `.opacity` for Reduce Motion;
   otherwise return
   `.opacity.combined(with: .scale(scale: 0.98, anchor: .top))`.
5. Wrap the current `dockerStorageDetail` conditional in `Group { ... }`, keep
   every current Docker label and row unchanged, and apply all of the
   following to the group:

   ```swift
   .id(dockerStoragePresentation)
   .transition(dockerStorageTransition)
   .animation(
       reduceMotion
           ? DesignTokens.Animation.reducedFeedback
           : DesignTokens.Animation.popoverContent,
       value: dockerStoragePresentation
   )
   ```

6. Do not add a transition to `ssdDetail`, `MetricTrendChart`, any compact
   metric value, or `OverlayManager` frame placement.

## Boundaries

- Do not animate CPU, RAM, network, SSD free-space, or AI numbers in the
  compact overlay.
- Do not alter Docker command execution, cache duration, parsing, storage, or
  error behavior in `DockerStorageService`.
- Do not add dependencies, timers, layout animations, or spring/bounce motion.
- If the popover content cannot transition without moving the overlay window,
  stop and report the issue rather than changing `setFrame(..., animate: false)`.

## Verification

- **Mechanical**:
  - Run `swift test`; it must pass with no new warnings.
  - Run `./script/build_and_run.sh --verify`; it must launch `cc-overlay`.
- **Feel check**:
  - Open the SSD popover on a Mac where Docker is available.
  - At 10% speed in Xcode's Debug > Slow Animations, open the popover with no
    cached Docker snapshot. Confirm the loading row fades/scales out and the
    result fades/scales in from the top without a bounce.
  - Repeat with macOS Reduce Motion enabled. Confirm only opacity changes;
    no scale or positional movement appears.
  - Drag the overlay while Docker data is present. Confirm the drop position
    remains exact and the panel does not animate after release.
- **Done when**: Docker result replacement is perceptible but completes in
  180ms, the overlay frame never interpolates, and unavailable Docker installs
  still show no Docker section.
