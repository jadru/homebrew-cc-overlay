# Brew Release Preparation (v0.7.0)

## Completed in this preparation
- App version constant/bundle version: bumped to `0.7.0`
- Release notes draft added (`RELEASE_NOTES.md`, `RELEASE_NOTES_KO.md`)
- Remaining work separated into documentation (`docs/plan/todo.md`)

## Pre-release checklist
1. Verify `swift build` / `swift test`
2. Final review of release notes
3. Create tag: `git tag v0.7.0 && git push origin v0.7.0`

## Post-tag automation
- `.github/workflows/release.yml` automatically:
  - Builds universal binary and uploads tarball
  - Calculates SHA-256
  - Updates `url`/`sha256` in `Formula/cc-overlay.rb`
  - Syncs to tap repository (`jadru/homebrew-cc-overlay`)

## Manual verification
1. Confirm asset/sha256 uploaded to GitHub Release
2. Confirm Formula reflects `v0.7.0` + new sha256
3. Local testing
   - `brew update`
   - `brew upgrade cc-overlay` or fresh install `brew install cc-overlay`
   - `brew services restart cc-overlay`
