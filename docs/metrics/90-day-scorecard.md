# 90-Day Product Scorecard

All targets are validation gates, not historical performance claims.

| Metric | Definition | Initial target | Decision it unlocks |
|---|---|---:|---|
| Landing intent rate | Release opens + install-command copies / unique visitors, per source | 15% | Keep or revise the ICP message |
| System-monitor activation | First visible system sample within 30 seconds of launch | 90% | Validate onboarding and startup reliability |
| Provider capacity activation | First usable Codex or Claude Code data within 3 minutes when configured | 70% | Improve provider setup and recovery |
| Combined-capacity utility | Interviewees who use both system and AI data in one pre-run decision | 10 of 15 | Keep one unified overlay |
| Overlay respectfulness | Users who retain the default display mode after one week | 80% | Keep the default always-visible bar |
| Reliability | Sessions without system sampler, provider, or update errors | 97% | Public launch readiness |
| Paid intent | Feedback respondents selecting $19+ | 30% | Build a Pro prototype |

## Measurement policy

- The landing uses cookie-free Vercel Web Analytics and named CTA events. These measure acquisition only.
- The macOS app does not upload system metrics, usage, credentials, project names, or behavioral events.
- First-launch and first-usable-data timestamps remain in local `UserDefaults` and appear only in user-copied safe diagnostics.
- Research participants opt in by sharing a safe diagnostic snapshot in a feedback issue or interview. The researcher records the denominator; the app never infers it from downloads.

## Weekly review

Every Monday record source-level visitor, CTA, release, consented system activation, provider activation, combined-capacity utility, issue, interview, and maintainer-support-hour counts. Keep raw counts beside percentages; cohorts below 30 users are directional only.
