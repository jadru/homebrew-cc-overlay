# ADR 0001: Companion progress is the primary product outcome

- Status: Accepted
- Date: 2026-08-18

## Context

CC-Overlay combines a pixel companion with provider headroom and next-run
guidance. Treating both as co-equal product goals created a diffuse message and
made it easy to grow utility features before proving that anyone returns for
the companion.

## Decision

The companion and its earned, local progression are the primary product
outcome. Provider monitoring, pacing, reset handling, and Run / Wait / Switch
guidance are supporting guardrails. They must remain truthful, quiet, and
optional; none may claim a level of task certainty that local evidence cannot
support.

## Consequences

- Prioritize companion activation and week-four companion return ahead of new
  dashboard features.
- Treat guardrail reliability and accessibility as release-blocking because
  they protect trust in the primary experience.
- Do not add a second gamification system or team dashboard without a separate
  validated user and buyer.
