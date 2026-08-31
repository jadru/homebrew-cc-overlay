# Product

## Register

Local-first macOS capacity copilot for Codex and Claude Code work.

## User and job to be done

CC-Overlay serves an individual macOS developer who works with Codex and/or Claude Code, notices system pressure or AI limits during intensive work, and wants to decide before starting a run.

> Before I start an AI coding run, help me see my Mac, provider headroom, and recent local project usage in one place so I can decide whether to run now and when to check again if I should wait.

It is not a team monitoring, billing, calendar, reminder, fleet-management, or provider-routing product. The user remains in control of the tool and the work they start.

## Product purpose

CC-Overlay makes both sides of a coding run legible without opening several status tools: whether the Mac can sustain the run and whether an AI provider has usable capacity. The compact overlay answers the first glance; the on-demand dashboard explains the recommendation.

The floating overlay works without provider authentication. Local Codex and Claude Code integrations enrich it with headroom, resets, seven-day trends, and project activity when data is available.

### Product hierarchy

1. **Decide before the run:** Present a clear Next action, a recommended provider when appropriate, the supporting reason, confidence, and a safe recheck time when one is known.
2. **Keep the essential signals visible:** Put CPU, memory, network, storage, AI headroom, and the dashboard within one compact surface that can be horizontal, vertical, or two-column.
3. **Explain local AI activity honestly:** Show project-level session and token context while distinguishing Claude API-equivalent estimates from Codex local-token data and never presenting Codex tokens as a bill.
4. **Earn trust through local boundaries:** Keep system samples in memory, make provider access explicit, reduce displayed project paths to their final directory name, and do not add transcripts or token ledgers to diagnostics or exports.
5. **Stay calm and controllable:** Keep the overlay optional, persistent in the chosen layout, accessible, draggable within the screen, full-screen compatible, and capable of click-through.

## Capacity decision model

`UsageDecision` selects from provider capacity. `CapacityDecision` then combines that result with the Mac state in this fixed priority order:

1. Critical memory pressure or thermal state: wait for the Mac.
2. Provider setup or fresh data is required: set up or refresh.
3. Provider limits, available resets, or a better provider require action: wait, use reset, or switch.
4. Warning system pressure, serious thermal state, CPU or memory at 90% or more, or less than 10 GiB free storage: run with caution and name the reason.
5. Otherwise: run now.

Network and battery are important context signals, but they are not independent blocking conditions in this version. A critical Mac state does not guess a recovery time; it asks the user to recheck when the Mac reports recovery. A provider wait uses the earliest known reset time as the next safe time.

## Product experience

| Moment | Surface | User outcome |
|---|---|---|
| Before starting work | Compact overlay | See the immediate Mac and AI constraint without leaving the current app. |
| Need a different footprint | Right-click Layout menu or Settings → Overlay | Switch instantly among horizontal, vertical, and two-column layouts; preserve the choice after restart. |
| Need an explanation | Metric popover | Inspect a focused system signal or seven-day AI headroom history without opening the full dashboard. |
| Need a decision | Dashboard | Read Next action, reasons, confidence, suggested provider, and next safe time. |
| Need recent local context | Usage details → Project activity | See the last 24 hours grouped by project with transparent data-source labels. |

## Data-source contract

| Source | What CC-Overlay uses | What it must not imply |
|---|---|---|
| Codex app-server and OAuth metadata | Rate-limit windows, resets, and headroom | A calculated Codex dollar cost or a new storage location for credentials. |
| Codex local rollouts | Positive increments of cumulative token counters joined to `session_meta.cwd` | That repeated events are new tokens, or that local tokens equal billed usage. |
| Claude OAuth | Opt-in current rate-limit information | Permission to read a credential before the user enables it. |
| Claude local JSONL | Session, project, model, token aggregation, and optional API-equivalent estimate | An actual invoice or persisted transcript export. |
| Mac system APIs | Current and recent CPU, memory, network, storage, battery, thermal, and process state | Remote monitoring or durable system telemetry. |

## North-star measure and validation

The north-star measure is the percentage of users who resolve a weekly pre-run capacity decision from one screen. CC-Overlay adds no automatic remote product telemetry for this measure; it uses consent-based interviews and safe diagnostics.

| Hypothesis | Evidence required |
|---|---|
| The combined surface makes a decision quickly | 12 of 15 target users identify the Mac constraint, AI constraint, and next action within 10 seconds. |
| The product reduces status-tool context switching | 8 of 15 target users report fewer separate checks of Activity Monitor and provider status pages after a week. |
| Layout choice remains understandable | Users can switch layouts with the context menu and predict that the choice will persist after restart. |
| Cost language remains trustworthy | Users do not mistake Codex local tokens or the Claude API-equivalent estimate for an actual bill. |
| Local-only boundaries earn trust | Users do not expect system metrics, raw paths, transcripts, or token ledgers to leave the Mac after reading the app copy. |

## Brand personality

Technical, calm, and precise. The visual language should feel like a well-made instrument panel: compact enough for daily use, clear enough under pressure, and never theatrical.

## Design principles

1. Show the constraint before the decoration.
2. Make the action and its reason explicit.
3. Keep system monitoring useful even when no AI provider is configured.
4. Make unavailable, stale, first-sample, and estimate states explicit rather than guessed.
5. Keep cost language tied to its data source; never turn local activity into a false invoice.
6. Respect pointer input, screen boundaries, full-screen apps, and Reduce Motion.

## Accessibility and inclusion

Every overlay metric, layout choice, context-menu state, and dashboard action has a clear accessibility label. The product respects macOS Reduce Motion and does not rely on color or animation alone to communicate a constrained system or provider limit.
