# CC-Overlay Launch Kit

**Category:** local-first macOS system and AI capacity monitor.

**One line:** CC-Overlay keeps your Mac's CPU, memory, network, thermal state, and Codex or Claude Code headroom in one compact overlay.

## Core message

Before starting an intensive AI-assisted coding run, developers need to know both whether their Mac has room and whether their provider has room. CC-Overlay provides that answer without sending system metrics off the Mac.

## Proof points

- Compact floating bar with CPU, RAM, network, SSD free space, and the tightest available provider limit.
- Clickable compact-bar detail popovers plus an on-demand dashboard panel with 60-minute system trends, accessible top processes, SSD capacity, battery, and thermal state.
- Local Codex and Claude Code rate limits, reset times, and pace when configured.
- System monitoring still works without an AI provider.
- Signed, notarized, universal macOS release with Homebrew installation.

## Suggested Show HN post

**Title:** Show HN: CC-Overlay – a local macOS overlay for system and AI capacity

I built CC-Overlay because an intensive coding run can fail for two unrelated-looking reasons: the Mac is under pressure, or Codex/Claude Code is close to a limit. It is a native macOS overlay with an on-demand dashboard that puts CPU, memory, network, thermal state, and provider headroom in the same place. System metrics stay in a 60-minute in-memory buffer and never leave the Mac.

I would especially value feedback from people who use Codex or Claude Code several times a week: does the compact bar answer the capacity question without becoming another dashboard?

## Release checklist

- Capture compact-bar detail popovers, the full on-demand dashboard, and developer-tools-only states.
- Verify first-sample placeholders and a desktop Mac with no battery.
- Verify memory and thermal alerts, click-through, drag bounds, full-screen behavior, and Reduce Motion.
- Run `swift test` and the universal packaging validation before publication.
