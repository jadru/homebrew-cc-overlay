# 002 — Show AI refresh progress in the popover

- **Status**: TODO
- **Commit**: c7f27d6
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 2 source files, about 25 lines

## Problem

The AI popover has a refresh icon that invokes a potentially asynchronous
provider refresh, but it gives no local indication that the request has
started. The icon remains tappable until `MultiProviderUsageService` changes
elsewhere, so the user cannot distinguish a pending refresh from a missed
click.

```swift
// Sources/CCOverlay/Views/MenuBar/SystemCapacityDashboardView.swift:187-198 — current
@ViewBuilder
private var aiUsageDetailPopover: some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Spacer()
            Button("Details", action: onOpenUsage)
                .controlSize(.mini)
            Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .accessibilityLabel("Refresh provider usage")
        }
        // provider rows and seven-day chart
    }
}
```

## Target

While `multiService.isLoading` is true, replace the refresh icon with the
native mini `ProgressView`, disable the refresh button, and announce
"Refreshing provider usage" to accessibility. When loading finishes, restore
the refresh icon. Crossfade the two same-sized symbols with opacity only:

- normal motion: `DesignTokens.Animation.popoverContent`, exactly
  `SwiftUI.Animation.easeOut(duration: 0.18)`;
- Reduce Motion: `DesignTokens.Animation.reducedFeedback`, exactly
  `SwiftUI.Animation.easeOut(duration: 0.12)`.

Do not rotate the SF Symbol manually, count up the provider percentage, or
show a checkmark: a failed request must not look successful. The existing
provider data/error state remains the outcome signal.

```swift
// Target button structure
Button(action: onRefresh) {
    ZStack {
        if multiService.isLoading {
            ProgressView()
                .controlSize(.mini)
                .transition(.opacity)
        } else {
            Image(systemName: "arrow.clockwise")
                .transition(.opacity)
        }
    }
    .frame(width: 12, height: 12)
}
.buttonStyle(.borderless)
.controlSize(.mini)
.disabled(multiService.isLoading)
.animation(refreshFeedbackAnimation, value: multiService.isLoading)
```

## Repo conventions to follow

- Plan `001-animate-docker-storage-replacement.md` adds the shared
  `DesignTokens.Animation.popoverContent` token. Execute that plan first.
- `Sources/CCOverlay/Views/Components/UpdateBannerView.swift:6,24-29` is the
  existing Reduce Motion pattern: obtain
  `@Environment(\.accessibilityReduceMotion)` and choose the motion token at
  the view boundary.
- `MultiProviderUsageService.refresh()` already owns the refresh lifecycle.
  The view must observe `multiService.isLoading`; it must not create another
  task, timer, or request state machine.

## Steps

1. Execute plan `001-animate-docker-storage-replacement.md` first so
   `DesignTokens.Animation.popoverContent` exists.
2. In `Sources/CCOverlay/Views/MenuBar/SystemCapacityDashboardView.swift`, add
   `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to
   `SystemCapacityDashboardView`.
3. Add a private computed animation named `refreshFeedbackAnimation` that
   returns `DesignTokens.Animation.reducedFeedback` when `reduceMotion` is
   true and `DesignTokens.Animation.popoverContent` otherwise.
4. Replace only the refresh `Button` at current lines 194-197 with the target
   `ZStack` structure above. Give both icon states a 12 by 12 point frame so
   the header does not reflow.
5. Keep `onRefresh` as the action. Add `.disabled(multiService.isLoading)`.
   Set the accessibility label to `"Refreshing provider usage"` while loading
   and `"Refresh provider usage"` otherwise. Add an accessibility value of
   `"In progress"` only while loading.
6. Keep the `Details` button, provider rows, reset labels, progress bars, and
   `AIUsageTrendChart` unchanged. Do not animate their values.

## Boundaries

- Do not add a success checkmark, a timer, a polling loop, or a second call to
  `onRefresh`.
- Do not animate compact overlay metrics, menu-bar label values, charts, or
  system samples.
- Do not modify `MultiProviderUsageService`, provider networking, error
  normalization, or the popover's width.
- Do not add dependencies.

## Verification

- **Mechanical**:
  - Run `swift test`; it must pass with no new warnings.
  - Run `./script/build_and_run.sh --verify`; it must launch `cc-overlay`.
- **Feel check**:
  - Open the AI popover and click refresh. Confirm that the icon immediately
    crossfades to the native mini spinner, the button becomes disabled, and a
    second click cannot enqueue a second refresh.
  - Complete a successful refresh and a forced failed refresh. In both cases,
    confirm that the spinner crossfades back to the refresh icon; only the
    provider/error content communicates the final outcome.
  - With Reduce Motion enabled, confirm the replacement uses opacity only and
    never shifts the Details button or provider rows.
  - At 10% speed in Xcode's Debug > Slow Animations, verify a 180ms normal
    crossfade and no bounce or count-up effect.
- **Done when**: refresh progress is unambiguous, duplicate refreshes are
  blocked while loading, and no real-time usage number is animated.
