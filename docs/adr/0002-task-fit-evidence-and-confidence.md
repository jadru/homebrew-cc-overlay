# ADR 0002: Task-fit confidence requires explicit recorded outcomes

- Status: Accepted
- Date: 2026-08-18

## Context

Passive headroom changes cannot identify which task consumed a provider limit.
Using them as task-fit evidence can produce an unjustified “safe” signal.

## Decision

Keep passive headroom history for pace forecasting only. Estimate task fit only
from explicit completed or limit-hit outcomes for the same provider and task
size. Five outcomes unlock an estimate; twelve recorded outcomes are required
before a live, likely-fit recommendation can be high confidence. Safe
diagnostics expose aggregate likely-fit calibration, including its false-safe
rate, without exposing task content, project names, paths, or usage history.

## Consequences

- New installations initially show “Learning your usage” or medium confidence.
- The product is more conservative but its confidence label is meaningful.
- Outcome recording becomes a key consented research instrument and needs
  regression coverage whenever its schema changes.
