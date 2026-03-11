# v0.8.0

## Menubar Refresh, Overlay Navigation, Provider Parsing Hardening

> [한국어](RELEASE_NOTES_KO.md)

### Highlights

- **Menubar redesign** — Wider scrollable panel, clearer provider header, quick action cluster, and richer empty-state guidance
- **Cross-provider summary cards** — New compact/standard provider summary cards for fast comparison across Claude Code, Codex, and Gemini
- **Overlay drill-down** — Expanded pill now supports provider selection, pinned expansion, session reset/last-active details, and better stale-state cues
- **Settings cleanup** — App settings are regrouped into clearer sections, with advanced credentials and fallback tuning hidden behind disclosure controls
- **Claude OAuth parsing hardening** — OAuth usage parsing now handles nested payload shapes, safer malformed responses, normalized plan identifiers, and Keychain access-denied handling
- **Better limit normalization** — Claude fallback estimation now uses detected plan tiers and session exhaustion prediction; Codex gauges now reflect the most constrained active window with friendlier labels
- **Regression coverage** — Added focused tests for OAuth response parsing and provider usage normalization

### Brew Release Notes

- Release automation (`.github/workflows/release.yml`) updates Homebrew formula URL/SHA automatically from tag and syncs to the tap repo
- For this release, create/push tag: `v0.8.0`

---

# v0.7.0

## Quick Wins: Stability, Security, Accessibility

> [한국어](RELEASE_NOTES_KO.md)

### Highlights

- **Provider architecture hardening** — `fetchUsage()` is now explicitly part of provider protocol contracts; base implementation no longer crashes with `fatalError`
- **Cost budget controls in Settings** — Added Claude plan tier picker and custom weighted limit input
- **Stale data indicator** — Menu bar and floating pill now show stale-state warning when data is older than `2x refresh interval`
- **Custom alert thresholds** — Warning/Critical thresholds are now user-configurable in Settings and used by alert notifications
- **API key security migration** — Codex/Gemini manual API keys moved from plain UserDefaults into Keychain with automatic legacy migration
- **VoiceOver improvements** — Accessibility labels/values added for menu bar status, overlay status, and refresh action

### Brew Release Notes

- Release automation (`.github/workflows/release.yml`) updates Homebrew formula URL/SHA automatically from tag and syncs to tap repo
- For this release, create/push tag: `v0.7.0`

---

# v0.6.0

## Homebrew OTA Auto-Update

> [한국어](RELEASE_NOTES_KO.md)

### New Features

- **Automatic update check** — Checks GitHub Releases API on app launch (after 3s delay) and every 24 hours for new versions
- **Menu bar update badge** — Blue dot appears on the menu bar icon when an update is available
- **Update banner** — In-app banner in the menu bar dropdown with three states:
  - **Update available** (blue) — Shows new version with "Update Now" / dismiss buttons
  - **Installing** — Progress indicator during `brew update && brew upgrade`
  - **Ready to restart** (green) — "Restart Now" / "Later" buttons after successful install
- **Settings > Updates section** — Toggle automatic updates, view current version, last check time, and manual "Check for Updates" button with live status indicator
- **CI version injection** — Release workflow now auto-injects version from git tag into source before building

### Internal

- Added `AppConstants.version`, `AppConstants.githubRepo`, `AppConstants.updateCheckInterval` constants
- Added `AppSettings.autoUpdateEnabled` (Bool) and `AppSettings.lastUpdateCheck` (Date?) with UserDefaults backing
- New `UpdateService` (`@Observable @MainActor`) — GitHub API check, semantic version comparison, brew update/upgrade via `/bin/bash -l -c`, restart via `brew services restart`
- New `UpdateBannerView` — Follows `ErrorBannerView` glass-effect pattern with blue/green tints
- Updated `MenuBarLabel`, `MenuBarView`, `SettingsView`, `CCOverlayApp`, `AppDelegate`, `WindowCoordinator` to wire `UpdateService` through the app lifecycle
- Added "Inject version" step to `.github/workflows/release.yml`

### Files Changed

- Modified: 10 files
- Added: 2 files

---

# v0.5.0

## Multi-Provider: Codex CLI Support

> [한국어](RELEASE_NOTES_KO.md)

### New Features

- **Multi-provider architecture** — CC-Overlay now monitors both **Claude Code** and **OpenAI Codex CLI** usage simultaneously
- **Automatic CLI detection** — Detects installed CLIs (Claude Code via `~/.claude`, Codex via Homebrew/npm/`~/.local/bin`) and their OAuth credentials
- **Codex CLI integration** — Real-time usage monitoring via OpenAI API: rate limits, credit balance, cost estimates
- **Provider tab sidebar** — Switch between Claude Code and Codex views in the menu bar dropdown
- **Provider badges** — Visual status indicators for each provider (active, unavailable, warning)
- **Codex credits card** — Displays plan type, credit balance, and extra usage status
- **Codex rate windows card** — Daily/weekly rate limit breakdown with reset timers
- **Provider-specific settings** — Enable/disable each provider independently; manual Codex API key option

### Improvements

- **Normalized usage model** — `ProviderUsageData` provides a unified data structure for any CLI provider
- **Critical provider tracking** — Floating pill and menu bar automatically show the provider closest to its limits
- **Backward-compatible** — Existing Claude Code-only users see no UI changes; Codex features appear only when detected

### Internal

- Added `CLIProvider` enum (`.claudeCode`, `.codex`) and `BillingMode` enum
- Added `ProviderUsageData`, `RateBucket`, `CostSummary`, `CreditsDisplayInfo`, `DetailedRateWindow` models
- New `MultiProviderUsageService` coordinator managing per-provider services
- New `ClaudeCodeProviderService` wrapping existing `UsageDataService`
- New Codex service layer: `CodexDetector`, `CodexOAuthService`, `CodexProviderService`, `OpenAIAPIService`, `OpenAICostCalculator`
- New UI components: `ProviderTabSidebar`, `ProviderBadge`, `ProviderSectionView`, `CreditsInfoCardView`, `RateWindowsCardView`
- Added `cc-overlay.entitlements` for network client capability
- Removed bundled `CC-Overlay.app` binary from source tree

### Files Changed

- Modified: 17 files
- Added: 10 files
- Deleted: 2 files
