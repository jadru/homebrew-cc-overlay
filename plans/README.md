# Animation plans

| # | Plan | Severity | Status | Dependency |
|---|---|---|---|---|
| 001 | [Smooth the Docker storage result replacement](001-animate-docker-storage-replacement.md) | LOW | TODO | None |
| 002 | [Show AI refresh progress in the popover](002-add-ai-refresh-progress-feedback.md) | LOW | TODO | 001 |

Execute plan 001 first because it defines the shared 180ms popover-content
motion token. Plan 002 reuses that token for the AI refresh feedback.

Neither plan animates the compact overlay's CPU, RAM, network, SSD, or AI
numbers. Those values refresh too frequently for decorative motion.
