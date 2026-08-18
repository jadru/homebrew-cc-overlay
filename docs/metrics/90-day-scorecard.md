# 90-Day Product Scorecard

All targets are validation gates, not historical performance claims.

| Metric | Definition | Initial target | Decision it unlocks |
|---|---|---:|---|
| Landing intent rate | Release opens + install-command copies / unique visitors, per source | 15% | Keep or revise ICP message |
| Companion activation | First usable provider data and first newly earned companion progress within 3 minutes | 70% | Scale distribution |
| W4 companion return | Consented user records companion progress on 3 distinct days in week four | 25% | Test paid companion extensions |
| Recommendation calibration | Limit hits / completed or limit-hit outcomes labelled “Likely fits” | Below 10%, n ≥ 30 | Keep guardrails supporting the pet loop |
| Companion delight | Interviewees who describe an earned companion moment unprompted | 7 of 10 | Continue roster investment |
| Guided-run success | Completed outcomes / guided runs with an outcome | 80% | Keep Run / Switch as a supporting action |
| Reliability | Sessions without provider/update errors | 97% | Public launch readiness |
| Paid intent | Feedback respondents selecting $19+ | 30% | Build a Pro prototype |

## Measurement Policy

- The landing uses cookie-free Vercel Web Analytics and named CTA events. These
  measure acquisition only; they never count as product retention.
- The macOS app does not upload usage, credentials, project names, or behavioral events.
- First-launch and first-usable-data timestamps remain in local `UserDefaults` and appear only in user-copied safe diagnostics.
- Task-fit samples require explicit recorded outcomes. Guided-run outcomes,
  calibration, and helpful/not-helpful votes remain local; safe diagnostics expose aggregate counts only.
- The research cohort opts in by sharing a safe diagnostic snapshot in a product
  feedback issue or interview. Its denominator is recorded by the researcher,
  never inferred from downloads.
- GitHub release downloads, Homebrew installs, issues, and opt-in interviews are
  distribution proxies—not activation or retention evidence.

## Weekly Review

Every Monday record source-level visitor, CTA, release, consented activation,
week-four companion return, likely-fit calibration, issue, interview, and
maintainer-support-hour counts. Keep raw counts beside percentages; cohorts
below 30 users are directional only.
