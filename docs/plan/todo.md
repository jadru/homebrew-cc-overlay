# CC Overlay Plan TODO (Progress)

Reference document: `.context/attachments/plan.md`

## Completed

### 1) Remove remaining `fatalError` calls
- ✅ Removed `fatalError` from `BaseProviderService`, replaced with no-op warning logs
- Target files:
  - `Sources/CCOverlay/Services/BaseProviderService.swift`
  - `Sources/CCOverlay/Services/ProviderServiceProtocol.swift`
- ✅ Reduced runtime crash points. `fatalError` now only remains in the ModelContainer final failure path during app initialization; most provider logic runs without termination
- Target files:
  - `Sources/CCOverlay/CCOverlayApp.swift`

### 6) VoiceOver accessibility audit
- ✅ Completed: Enhanced labels/structure in `CreditsInfoCardView`, `ProjectCostCardView`, `RateWindowsCardView`, `SegmentedProgressBar`, `SparklineView`, `ProviderBadge`, `ProviderSectionView`
- Target files:
  - `Sources/CCOverlay/Views/Components/CreditsInfoCardView.swift`
  - `Sources/CCOverlay/Views/Components/ProjectCostCardView.swift`
  - `Sources/CCOverlay/Views/Components/RateWindowsCardView.swift`
  - `Sources/CCOverlay/Views/Components/SegmentedProgressBar.swift`
  - `Sources/CCOverlay/Views/Components/SparklineView.swift`
  - `Sources/CCOverlay/Views/Components/ProviderBadge.swift`
  - `Sources/CCOverlay/Views/Components/ProviderSectionView.swift`

### 9) Usage history & trends
- ✅ Connected `UsageHistoryService` + sparkline data integration + UI card display (Claude)
- Target files:
  - `Sources/CCOverlay/Services/UsageHistoryService.swift`
  - `Sources/CCOverlay/Services/MultiProviderUsageService.swift`
  - `Sources/CCOverlay/Services/Claude/ClaudeCodeProviderService.swift`
  - `Sources/CCOverlay/Views/Components/ProviderSectionView.swift`
  - `Sources/CCOverlay/Views/Components/SparklineView.swift`

### 10) Rate limit exhaustion prediction
- ✅ Connected Claude API usage with snapshot-based prediction values
- Target files:
  - `Sources/CCOverlay/Services/Claude/ClaudeCodeProviderService.swift`
  - `Sources/CCOverlay/Models/ProviderUsageData.swift`
  - `Sources/CCOverlay/Utilities/RateLimitPredictor.swift`

### 11) Per-project cost analysis
- ✅ Exposed `UsageCalculator.aggregateByProject()` results and connected project cards
- Target files:
  - `Sources/CCOverlay/Services/UsageCalculator.swift`
  - `Sources/CCOverlay/Services/Claude/ClaudeCodeProviderService.swift`
  - `Sources/CCOverlay/Views/Components/ProviderSectionView.swift`
  - `Sources/CCOverlay/Views/Components/ProjectCostCardView.swift`

### 19) Session duration display
- ✅ Integrated `SessionMonitor` and active session card display
- Target files:
  - `Sources/CCOverlay/CCOverlayApp.swift`
  - `Sources/CCOverlay/Views/MenuBar/MenuBarView.swift`
  - `Sources/CCOverlay/Views/Components/ProviderSectionView.swift`
  - `Sources/CCOverlay/Views/Components/SessionCardView.swift`

### 7) OSLog integration
- ✅ Applied `AppLogger` multi-category cleanup (`service`, `network`, `auth`, `data`, `ui`)
- Target files:
  - `Sources/CCOverlay/Utilities/AppLogger.swift`

### 8) Intelligent Polling Backoff
- ✅ Implemented `lastActivityAt`-based exponential backoff (1.5x multiplier, max 4.0x, max 300s)
- Target files:
  - `Sources/CCOverlay/Services/BaseProviderService.swift`

### 12) Usage copy/export
- ✅ Connected usage summary copy and UsageSnapshot-based CSV copy/save functionality
- Target files:
  - `Sources/CCOverlay/Services/UsageExportService.swift`
  - `Sources/CCOverlay/Views/MenuBar/MenuBarView.swift`

### 13) Per-provider inline error display
- ✅ Added sidebar warning icon overlay and badge status indicators
- Target files:
  - `Sources/CCOverlay/Views/Components/ProviderTabSidebar.swift`

### 14) Keyboard navigation
- ✅ Implemented `↑/↓` provider switching and `R` shortcut for refresh
- Target files:
  - `Sources/CCOverlay/Views/MenuBar/MenuBarView.swift`

### 15) `NSUserNotification` → `UNUserNotificationCenter`
- ✅ Notification API modernization completed
- Target files:
  - `Sources/CCOverlay/Services/CostAlertManager.swift`

### 16) Per-model token tracking
- ✅ `ModelUsageSummary` + aggregation logic + per-model card display
- Target files:
  - `Sources/CCOverlay/Models/UsageData.swift`
  - `Sources/CCOverlay/Services/UsageCalculator.swift`
  - `Sources/CCOverlay/Views/Components/ModelBreakdownCardView.swift`
  - `Sources/CCOverlay/Views/Components/ProviderSectionView.swift`

### 17) Dark/Light glassmorphism optimization
- ✅ Enhanced per-OS brightness handling in `View+GlassCompatibility` using `Color.primary.opacity` fallback
- Target files:
  - `Sources/CCOverlay/Extensions/View+GlassCompatibility.swift`

### 18) Provider quick pause
- ✅ Implemented Pause/Resume context menu and state transitions on Provider Tab
- Target files:
  - `Sources/CCOverlay/Views/Components/ProviderTabSidebar.swift`
  - `Sources/CCOverlay/Views/MenuBar/MenuBarView.swift`

### 20) Provider Health Dashboard
- ✅ Displays auth/detection/last success/response latency status in card format
- Target files:
  - `Sources/CCOverlay/Models/ProviderUsageData.swift`
  - `Sources/CCOverlay/Services/UsageCalculator.swift`
  - `Sources/CCOverlay/Services/MultiProviderUsageService.swift`
  - `Sources/CCOverlay/Views/Components/ProviderHealthCardView.swift`
  - `Sources/CCOverlay/Views/Components/ProviderSectionView.swift`

## Remaining

- No items at this time
