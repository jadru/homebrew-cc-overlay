# Overlay Hover Expand/Collapse Redesign

Display the overlay as a tiny percentage pill by default, and smoothly expand it on mouse hover with animation to show full information.

## Core Behavior

- **Compact (default)**: Small glass capsule showing `72%` + color indicator only (~50x26)
- **Expanded (hover)**: Shows gauge ring + cost + sessions as currently (~130x180)
- **Transition**: Smooth morphing with spring animation
- Click-through mode always shows compact (hover detection unavailable)

## Modified Files

### `Sources/Amarillo/Views/Overlay/OverlayView.swift` (full rewrite)

State management with `@State private var isExpanded = false`.

**Compact state**:
```
┌──────────┐
│ ● 72%    │  ← color dot + percentage, glass capsule
└──────────┘
```
- tintColor dot (4px) + percentage text (size 13, bold, monospaced rounded)
- `.glassEffect(.regular.tint(tintColor.opacity(0.3)), in: .capsule)`
- padding: horizontal 10, vertical 6

**Expanded state**:
```
┌─────────────────┐
│    ╭──────╮     │
│    │  72% │     │ ← gauge ring (64x64)
│    │ left │     │
│    ╰──────╯     │
│     $3.50       │ ← cost
│    ● 2 active   │ ← sessions (only when present)
│                 │
│  5h 56% · 7d 72%│ ← rate limit windows (when API data available)
└─────────────────┘
```
- gauge ring: 64x64 (slightly reduced from current 72)
- All secondary text fades in with opacity transition
- `.glassEffect(.regular.tint(tintColor.opacity(0.3)), in: .rect(cornerRadius: 24))`
- padding: 14

**Animation**:
- `.onHover { hovering in withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded = hovering } }`
- gauge ring: `.scaleEffect` + `.opacity` transition
- Secondary text (cost, sessions, windows): `.opacity` + `.offset` transition (slides up from below)
- Compact percentage text: fades out with `.opacity(0)` when expanded

### `Sources/Amarillo/Views/Overlay/OverlayWindow.swift`

- Set `contentRect` to expanded max size (~180x220) instead of compact default
- Background is transparent so only the glass capsule is visible

### `Sources/Amarillo/Views/Overlay/OverlayWindowController.swift`

- Change `hostingView.frame` to match expanded max size (~180x220)
- Position calculation considers anchor direction based on `overlayPosition`:
  - topRight → anchored top-right, expands left+down
  - topLeft → anchored top-left, expands right+down
  - bottomRight → anchored bottom-right, expands left+up
  - bottomLeft → anchored bottom-left, expands right+up

Use `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment:)` in OverlayView to align to the appropriate corner.

Pass `settings.overlayPosition` to OverlayView for alignment calculation.

## Verification

1. `swift build` succeeds
2. Run app and verify overlay:
   - Default: small pill showing only percentage
   - Mouse hover: smoothly expands with spring animation
   - Mouse leave: smoothly collapses
3. Click-through mode always shows compact
4. All 4 positions expand in the correct direction
