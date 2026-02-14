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
