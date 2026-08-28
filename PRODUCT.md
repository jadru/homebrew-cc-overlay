# Product

## Register

Local-first system capacity overlay for AI-assisted macOS development.

## Users

CC-Overlay serves an individual macOS developer who runs Codex and/or Claude Code, notices performance pressure during intensive work, and needs a fast answer to two questions: “Is my Mac ready for this run?” and “Which AI provider still has usable capacity?” It is not a team monitoring or fleet-management product.

## Product purpose

CC-Overlay makes system capacity and AI work capacity legible without opening a dashboard. The floating bar works independently of provider authentication, while local provider integrations add rate limits and reset information when available.

### Product hierarchy

1. **Immediate system clarity:** CPU, memory pressure, network, storage, power, and thermal state are visible at a glance.
2. **Actionable AI capacity:** Codex and Claude Code headroom, resets, and pacing share the same surface as system conditions.
3. **Trustworthy local behavior:** System metrics remain in memory only; provider access stays explicit and transparent.
4. **Calm, controllable presentation:** The overlay is compact, optional, accessible, and stays out of the way of coding work.

### Validation hypotheses

| Hypothesis | Evidence required before scaling |
|---|---|
| The compact bar answers a pre-run capacity question quickly | 12 of 15 target users can identify both system and AI constraint within 10 seconds. |
| Combined capacity prevents unnecessary context switching | At least 8 of 15 target users report fewer separate checks of Activity Monitor and provider pages in a week. |
| The default overlay stays respectful | Fewer than 2 of 10 target users change away from the default after a week because it blocks work. |
| Local-only system collection earns trust | No participant expects their system metrics to leave the Mac after reading onboarding and Settings copy. |

## Brand personality

Technical, calm, and precise. The visual language should feel like a well-made instrument panel: compact enough for daily use, clear enough under pressure, and never theatrical.

## Design principles

1. Show the constraint before the decoration.
2. Keep system monitoring useful even when no AI provider is configured.
3. Make unavailable or first-sample values explicit rather than guessed.
4. Reserve alerts for actionable capacity risks.
5. Respect pointer input, screen boundaries, full-screen apps, and Reduce Motion.

## Accessibility and inclusion

Respect macOS Reduce Motion, preserve clear text labels for every visual state, and do not rely on color or animation alone to communicate a constrained system or provider limit.
