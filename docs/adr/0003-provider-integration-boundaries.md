# ADR 0003: Provider integrations are isolated, typed, and fail closed

- Status: Accepted
- Date: 2026-08-18

## Context

Provider credential formats and usage response shapes can change independently
of CC-Overlay. A missing implementation or malformed response must not crash
the menu-bar process or be interpreted as trusted usage data.

## Decision

Every provider service explicitly conforms to `ProviderServiceProtocol` and
implements usage fetching. The shared base service owns only lifecycle and
backoff behavior. Provider-specific parsers reject missing primary limits and
surface a recoverable health state. Local export is available only when a user
explicitly saves locally read transcript entries.

## Consequences

- New providers cannot silently inherit a fatal default implementation.
- Parser fixtures and health-state tests are part of every provider change.
- Provider incompatibility is a supported state, not a reason to weaken data
  quality labels or send local data elsewhere.
