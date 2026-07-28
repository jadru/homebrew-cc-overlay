# 90-Day Product Scorecard

All targets are validation gates, not historical performance claims.

| Metric | Definition | Initial target | Decision it unlocks |
|---|---|---:|---|
| Landing intent rate | Release opens + install-command copies / unique visitors | 15% | Keep or revise positioning |
| Activation | First usable provider data within 3 minutes of first launch | 70% | Scale distribution |
| W4 retained install | App still checking for releases or user-confirmed weekly use after 28 days | 25% | Test paid power features |
| Recommendation trust | Users rating Run / Wait / Switch as useful in interviews | 7 of 10 | Make recommendation the core wedge |
| Reliability | Sessions without provider/update errors | 97% | Public launch readiness |
| Paid intent | Feedback respondents selecting $19+ | 30% | Build a Pro prototype |

## Measurement Policy

- The landing uses cookie-free Vercel Web Analytics and named CTA events.
- The macOS app does not upload usage, credentials, project names, or behavioral events.
- First-launch and first-usable-data timestamps remain in local `UserDefaults` and appear only in user-copied safe diagnostics.
- GitHub release downloads, Homebrew installs, issues, and opt-in interviews are the distribution proxies.

## Weekly Review

Every Monday record visitor, CTA, release, activation-sample, issue, and interview counts. Keep raw counts beside percentages; cohorts below 30 users are directional only.
