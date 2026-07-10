# Design QA

## Final Result

passed

## Visual Evidence

- Selected target: `/Users/jadru/.codex/generated_images/019f457f-f83c-7381-8f9c-f8bd718ba191/exec-38e506d8-cbab-4d57-acb0-98c19b1d7e56.png`
- Rendered implementation: `/tmp/cc-overlay-design-qa/menu-bar-usage-timeline-flattened.png`
- Side-by-side comparison: `/tmp/cc-overlay-design-qa/design-comparison.png`

## Findings And Fixes

1. P1 - The previous panel repeated the same provider state in a summary rail, large circular gauge, and rate-limit pills. The menu bar now presents one remaining-usage summary followed by ordered 5H and 7D timeline rows.
2. P1 - Nested glass cards made the panel feel decorative and forced scrolling for the primary task. The timeline uses one grouped surface with dividers and direct labels instead.
3. P2 - The toolbar was read as a large blue action container. The same copy, refresh, settings, and quit actions remain as independent icon buttons.
4. P2 - A single provider unnecessarily displayed a selector rail. The rail is now shown only when multiple providers are available.

## Fidelity Review

- Typography: The summary uses a strong 34pt rounded percentage; timeline labels, status, and reset text use a compact system hierarchy suitable for scanning.
- Spacing and layout: 16pt panel insets, 14pt row separation, aligned timeline endpoints, and a 560pt maximum panel height prevent the long scrolling panel shown in the source screenshot.
- Colors: Neutral material is the primary surface. Amber reflects the cautionary 5H remaining state, mint reflects a healthy 7D pace, and gray is reserved for secondary information.
- Image quality: The existing provider SVG asset is retained. The offscreen AppKit capture does not rasterize that SVG, but its fixed 34pt slot and the runtime asset path are unchanged from the live panel.
- Copy and accessibility: Each rate window exposes remaining percentage, current usage, reset countdown, and pace status through visible text and accessibility labels.

## Accepted Differences

- The selected target omitted non-primary limits. The implementation keeps additional limits as one compact text row so active limits such as Spark remain available without returning to card-heavy UI.
- The target includes a duplicate reset callout on the right of the summary. The implementation keeps one reset statement in the summary and per-window reset values in the timelines to avoid repeating the same fact.
