# ADR 0001: System capacity and AI capacity share one overlay

- Status: Accepted
- Date: 2026-08-28

## Context

Developers often check Activity Monitor, battery or thermal state, and separate Codex or Claude Code usage pages before a demanding run. These conditions affect the same decision but were previously disconnected in the product.

## Decision

CC-Overlay is a local-first system capacity monitor with optional local provider integrations. Its compact floating surface always renders CPU, RAM, network, SSD free space, and the most constrained available provider. Clicking a metric opens only its focused detail popover. The trailing dashboard button opens an on-demand panel with SSD capacity, battery when present, thermal state, 60-minute trends, accessible top processes, and per-provider capacity details.

System metrics remain in a 60-minute in-memory ring buffer. They are not written to disk or sent to a service. Provider credentials, usage history, updates, login-start behavior, and the global shortcut remain separate existing concerns.

## Consequences

- The product provides value without a configured AI provider.
- System pressure and AI limits are visible at the moment a developer chooses whether to continue work.
- The app needs native macOS sampling, careful first-sample handling, and a low-overhead refresh cadence.
- Memory and thermal alerts are intentionally limited to actionable states; CPU, network, storage, and battery do not alert in v1.
