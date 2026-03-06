# UI Redesign: Liquid Glass + Dollar Cost Display

## Summary

1. Add API token-based **dollar ($) cost calculator** (with accurate per-model pricing)
2. **Overlay** — Redesigned with circular progress ring + glass squircle widget
3. **Menu bar popover** — `GlassEffectContainer` + glass card-based layout
4. **Menu bar label** — Added cost display

---

## Modified Files (10)

| File | Change |
|------|--------|
| `Models/CostCalculator.swift` | **New** — Per-model pricing, CostBreakdown, calculation logic |
| `Models/UsageData.swift` | Added `fiveHourCost`, `dailyCost` fields to `AggregatedUsage` |
| `Services/UsageCalculator.swift` | Added cost calculation call in `aggregate()` |
| `Utilities/NumberFormatting.swift` | Added `formatDollarCost()`, `formatDollarCompact()` |
| `Views/Overlay/OverlayView.swift` | **Full rewrite** — Circular ring + glass squircle |
| `Views/Overlay/OverlayWindow.swift` | Window size 160x90 → 140x140 |
| `Views/Overlay/OverlayWindowController.swift` | hostingView size sync |
| `Views/MenuBar/MenuBarView.swift` | **Full rewrite** — Glass card-based |
| `Views/MenuBar/MenuBarLabel.swift` | Added dollar cost display |
| `Tests/CostCalculatorTests.swift` | **New** — Price lookup, cost calculation tests |

---

## 1. CostCalculator (New File)

`Sources/Amarillo/Models/CostCalculator.swift`

### Per-Model Pricing Table

| Model prefix | Input/MTok | Output/MTok | Cache Write/MTok | Cache Read/MTok |
|------------|-----------|------------|-----------------|----------------|
| `claude-opus-4` | $15 | $75 | $18.75 | $1.50 |
| `claude-sonnet-4` | $3 | $15 | $3.75 | $0.30 |
| `claude-3-5-haiku` | $0.80 | $4 | $1.00 | $0.08 |
| fallback (unknown) | $3 | $15 | $3.75 | $0.30 |

### Structs

- `ModelPricing` — 4 per-MTok rates per model
- `CostBreakdown` — input/output/cacheWrite/cacheRead costs + `totalCost` computation + `+` operator
- `CostCalculator.cost(for: ParsedUsageEntry)` — Per-entry cost
- `CostCalculator.cost(for: [ParsedUsageEntry])` — Sum of entry array costs
- `CostCalculator.cost(for: SessionUsage)` — Per-session cost

Key: `TokenUsage` has no model information so cost cannot be calculated directly. Always calculate at the `ParsedUsageEntry` level (which includes model) then aggregate.

---

## 2. UsageData.swift Changes

Add 2 fields to `AggregatedUsage`:

```swift
struct AggregatedUsage: Sendable {
    // ... existing fields ...
    let fiveHourCost: CostBreakdown   // 5-hour window cost
    let dailyCost: CostBreakdown      // Today's cost
}
```

Update `.empty` static with `.zero` values.

---

## 3. UsageCalculator.swift Changes

Add CostCalculator call in `aggregate()` method:

```swift
let windowCost = CostCalculator.cost(for: windowEntries)
let dailyCost = CostCalculator.cost(for: dailyEntries)
// Pass to AggregatedUsage initializer
```

---

## 4. NumberFormatting.swift Changes

Add 2 functions:

```swift
static func formatDollarCost(_ amount: Double) -> String
// 0.42 → "$0.42", 3.7 → "$3.70", 0.001 → "<$0.01"

static func formatDollarCompact(_ amount: Double) -> String
// 0.42 → "42c", 3.70 → "$3.70", 0.001 → "<1c"
```

---

## 5. Overlay Redesign

`OverlayView.swift` — Full rewrite

### Design Concept

Current (capsule + text only) → **Circular progress ring** centered glass squircle widget

```
┌──────────────────┐
│                  │
│    ╭──────╮      │
│    │ ring │      │  ← 72x72 progress ring
│    │ 44%  │      │     Remaining % centered
│    │ left │      │
│    ╰──────╯      │
│     $3.70        │  ← 5-hour cost
│                  │
└──────────────────┘
 .glassEffect(.regular.tint(color), in: .rect(cornerRadius: 28))
```

### View Structure

```swift
VStack(spacing: 6) {
    // Progress ring
    ZStack {
        Circle().stroke(secondary 0.15, lineWidth: 5)        // Background track
        Circle().trim(0...usedPct/100).stroke(tint, 5pt)     // Progress arc (animated)
        VStack {
            Text("44%")  // 20pt bold rounded
            Text("left") // 9pt medium secondary
        }
    }
    .frame(72x72)

    // Cost label
    Text("$3.70")  // 11pt semibold rounded secondary
}
.padding(16)
.glassEffect(.regular.tint(tintColor.opacity(0.3)), in: .rect(cornerRadius: 28))
```

### Color Logic (tintColor)

- remainPct <= 10 → `.red`
- remainPct <= 30 → `.orange`
- remainPct <= 60 → `.yellow`
- else → `.green`

Tint uses `opacity(0.3)` to maintain glass transparency.

### Window Size Changes

- `OverlayWindow.swift` contentRect: 160x90 → **140x140**
- `OverlayWindowController.swift` hostingView.frame: 160x90 → **140x140**

---

## 6. Menu Bar Popover Redesign

`MenuBarView.swift` — Full rewrite

### Design Concept

Wrap everything in `GlassEffectContainer`, represent each section as glass cards.

### Layout (width: 300)

```
┌─ GlassEffectContainer ──────────────────┐
│                                         │
│  Claude Code           [⟳]  ← glass circle interactive refresh
│  Max ($100/mo)                          │
│                                         │
│  ┌─ glass card (primary gauge) ────────┐│
│  │  Session Limit                      ││
│  │       ╭──────╮                      ││
│  │       │ ring │  88x88               ││
│  │       │ 44%  │                      ││
│  │       │ rem  │                      ││
│  │       ╰──────╯                      ││
│  │  [5h 56%] [7d 72%] [Sonnet 12%]    ││  ← glass capsule pills
│  │  ⏰ Resets in 3h            ● Live  ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─ glass card (cost) ────────────────┐ │
│  │  Estimated Cost           $        │ │
│  │     $3.70      │     $12.45        │ │
│  │    5h window    │     today         │ │
│  │  ● In $0.12  ● Out $2.80  ...     │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ┌─ glass card (tokens) ──────────────┐ │
│  │  5-Hour Tokens                     │ │
│  │  (existing TokenBreakdownView)     │ │
│  └────────────────────────────────────┘ │
│                                         │
│  [Overlay toggle]         [⚙ Settings]  │  ← Settings button: glass capsule interactive
│                                         │
│  Updated 30s ago                        │
│                                         │
└─────────────────────────────────────────┘
```

### Glass Usage Points

- Overall: `GlassEffectContainer { ... }` — Visual unification for child glass elements
- Refresh button: `.glassEffect(.regular.interactive(), in: .circle)` — Bounces on press
- Primary gauge card: `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
- Window pills (5h/7d/Sonnet): `.glassEffect(.regular, in: .capsule)` — Glass capsules
- Cost card: `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
- Token breakdown card: `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
- Settings button: `.glassEffect(.regular.interactive(), in: .capsule)`

### Helper Functions

- `windowPill(label, bucket)` — Glass capsule pill view
- `costChip(label, amount, color)` — Color dot + cost text
- `windowLabel(String)` — "five_hour" → "Session Limit"
- `formatPlanName(String)` — "max_5" → "Max ($100/mo)"

---

## 7. Menu Bar Label Changes

`MenuBarLabel.swift` — Optional cost display

```swift
HStack(spacing: 4) {
    Image(systemName: "chart.bar.fill")
    if hasData {
        Text("44%")           // Existing: remaining %
        if cost > 0 {
            Text("$3.70")     // New: 5-hour cost (caption2, secondary)
        }
    }
}
```

---

## Implementation Order

1. Create `CostCalculator.swift` + `CostCalculatorTests.swift`
2. `UsageData.swift` — Add cost fields to `AggregatedUsage`
3. `UsageCalculator.swift` — Add cost calculation in `aggregate()`
4. `NumberFormatting.swift` — Add dollar format functions
5. `OverlayView.swift` — Full rewrite
6. `OverlayWindow.swift` — Size change (140x140)
7. `OverlayWindowController.swift` — Size sync
8. `MenuBarView.swift` — Full rewrite
9. `MenuBarLabel.swift` — Add cost display

---

## Verification

1. `swift build` succeeds
2. `swift test` — CostCalculator tests pass
3. Run app → Verify circular ring + cost display on overlay
4. Verify glass card layout in menu bar popover
5. Verify costs are in reasonable range (~$0–$50 for 5-hour usage)
6. Verify color tint changes based on usage level
