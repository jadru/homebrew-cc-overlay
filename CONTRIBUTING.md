# Contributing

CC-Overlay welcomes focused bug fixes, tests, documentation improvements, and design changes that preserve the app's quiet menu bar workflow.

## Development

Requirements: macOS 15 or later and Swift 6 or later.

```bash
git clone https://github.com/jadru/homebrew-cc-overlay.git
cd homebrew-cc-overlay
swift test --disable-sandbox
./script/build_and_run.sh
```

The local app is ad-hoc signed for development. Do not treat it as a notarized release.

## Before Opening a Pull Request

```bash
swift test --disable-sandbox
ruby -c Formula/cc-overlay.rb
VERSION=0.0.0 BUILD_NUMBER=0 SIGN_IDENTITY=- NOTARIZE=0 ARCHS="arm64 x86_64" ./script/package_release.sh
git diff --check
```

Keep changes scoped, add regression coverage for behavior changes, and update both README files when user-facing behavior changes. Do not add provider credentials, local transcripts, release archives, or derived usage data to Git.

## Provider Integrations

Provider tokens and local CLI data are sensitive. Do not log tokens, commit captured responses, or add new provider integrations without documenting their data source, user consent, failure behavior, and licensing status.

## Releases

Maintainers publish signed and notarized releases from tags through the GitHub Actions release workflow. Homebrew formula updates are automated from the generated archive checksum.
