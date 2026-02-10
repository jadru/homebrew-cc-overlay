# v0.2.0

## Enterprise Quota & Pricing Update

> [한국어](RELEASE_NOTES_KO.md)

### New Features

- **Enterprise plan quota display** — When your subscription is Enterprise-based, CC-Overlay now shows a 3-tier spending limit breakdown:
  - **Individual seat** cap (primary, emphasized)
  - **Seat tier** cap (Standard / Premium aggregate)
  - **Organization** cap (full org aggregate)
  - Each limit shows used/cap dollars, color-coded utilization, and reset countdown
- **Enterprise quota card** in the menu bar dropdown panel
- **Enterprise seat remaining** in the floating pill (expanded state) and menu bar label
- **Enterprise settings section** showing organization name, seat tier, and all spending limits

### Improvements

- **Updated model pricing** — Accurate per-MTok rates for the latest models:
  - Added Opus 4.5/4.6 ($5/$25) and Opus 4.0/4.1 ($15/$75) as separate entries
  - Added Haiku 4.5 ($1/$5)
- **Consolidated `formatPlanName`** — Removed 3 duplicate helper functions, replaced with single `PlanTier.displayName(for:)` static method
- **CI/CD hardening** — SHA-256 verification step in release workflow, improved Homebrew tap sync with `TAP_TOKEN` support

### Internal

- Added `SpendingLimit`, `EnterpriseSeatTier`, `EnterpriseQuota` data models
- Extended `AnthropicAPIService` to parse enterprise quota from OAuth API response
- Extended `UsageDataService`, `UsageDataServiceProtocol`, `MenuBarViewModel` with enterprise properties
- New `EnterpriseQuotaCardView` component with 3 preview states

### Files Changed

- Modified: 14 files
- Added: 1 file (`EnterpriseQuotaCardView.swift`)
