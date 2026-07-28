# Design QA

## Scope

- Reference: `design/reference-option-2.png`
- Implementation: `src/App.jsx`, `src/styles.css`
- Target state: light theme, English-first landing page
- Matched artboard: 864 × 1821 CSS px, top of page
- Desktop check: 1422 × 800 CSS px
- Mobile check: 433 × 938 CSS px

## Visual comparison evidence

- Matched side-by-side comparison: `design/qa-90day-comparison.png`
- Desktop hero capture: `design/implementation-90day-hero-final.png`
- Mobile hero capture: `design/implementation-90day-mobile-final.png`

The reference and implementation were compared at the same 864 × 1821 viewport and top-of-page state. The browser capture used a 0.9 device scale and was normalized to the reference's 864 × 1821 pixels before the combined review.

## Review findings

### Typography and layout

- Archivo Variable preserves the dense grotesk display character; IBM Plex Mono carries labels, metadata, commands, and supporting copy.
- The warm-paper canvas, thin rules, vertical annotation, oversized headline, status rail, and editorial section rhythm remain faithful to the selected direction.
- The production page intentionally extends the source composition with a real-product proof section and install instructions. These additions reuse the same grid, rules, type, and spacing language.
- The desktop and mobile documents have no horizontal overflow.

### Product fidelity and assets

- The primary CTA opens the real latest-release URL and the install command is the current Homebrew command.
- The product image is an actual CC-Overlay capture, not a placeholder or reconstructed asset.
- Interface icons come from Phosphor and fonts are bundled locally through Fontsource.
- No fabricated version, testimonial, pricing claim, or telemetry claim appears on the landing page.

### Interaction and accessibility

- Theme toggle changes state and accessible label in both directions.
- Install command copy succeeds; QA uncovered and fixed the no-clipboard-permission fallback before the final pass.
- Release, source, install notes, and privacy destinations were verified.
- Skip navigation, semantic landmarks, focus states, accessible labels, and reduced-motion behavior are present.
- Browser console contains no errors or warnings.

## Verification

- `npm run build`: passed
- `npm run test:sites`: passed (4/4)
- Desktop width: client 1422 px, scroll 1422 px
- Mobile width: client 433 px, scroll 433 px
- Swift/XCTest: 104 passed
- Swift Testing: 39 passed
- Issue-template YAML: valid
- `git diff --check`: passed

## Iteration history

1. Initial desktop review found the install command and live status rail competing vertically; hero height was increased and rechecked.
2. Mobile interaction review found clipboard writes could fail when permission was unavailable; a local fallback was added and rechecked.
3. Final matched-artboard comparison found no P0, P1, or P2 visual defect.

final result: passed
