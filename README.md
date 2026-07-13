# CC-Overlay

> [한국어](README_KO.md) | [Release Notes](RELEASE_NOTES.md) ([한국어](RELEASE_NOTES_KO.md)) | [Contributing](CONTRIBUTING.md) | [Security](SECURITY.md)

macOS menu bar app that monitors your **Claude Code** and **Codex CLI** usage in real time.

CC-Overlay is an independent, open-source utility distributed directly through GitHub Releases and Homebrew. It is not affiliated with, endorsed by, or supported by Anthropic or OpenAI.

## Features

- **Multi-provider monitoring** — Track Claude Code and OpenAI Codex CLI usage simultaneously
- **Authenticated-only display** — Unconfigured providers never appear as misleading setup or usage indicators
- **Live rate-limit windows** — 5-hour and 7-day rate-limit data from Claude Code and Codex OAuth
- **Local fallback, clearly labeled** — Claude JSONL estimates are marked with `~` and "local estimate"
- **Floating Liquid Glass overlay** — A compact, screen-bounded status surface that expands on hover
- **Pacing signals** — 5H and 7D timelines distinguish fast burn, on-pace, and plenty-left states
- **Provider switcher** — A compact selector appears only when both providers have usable data
- **Cost threshold alerts** — macOS notifications at 70% and 90% usage
- **Global hotkey** — Toggle overlay with `Cmd+Shift+A`

## Distribution and Trust

Tagged releases are built as universal Apple Silicon and Intel app bundles, signed with a Developer ID Application certificate using the hardened runtime, notarized by Apple, and stapled before publication. The release workflow also validates the app signature, bundle contents, clean archive, and SHA-256 checksum.

Homebrew installs the signed `CC-Overlay.app` bundle without re-signing it. Verify an installed release with:

```bash
APP="$(brew --prefix cc-overlay)/CC-Overlay.app"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
```

For a manual GitHub Release download, verify the published checksum before opening the archive:

```bash
shasum -a 256 -c CC-Overlay-vX.Y.Z-macos.zip.sha256
```

Local builds created with `script/build_and_run.sh` are ad-hoc signed for development. They are not release artifacts.

## Install

### Homebrew

```bash
brew tap jadru/cc-overlay
brew install cc-overlay
cc-overlay
```

Enable **Launch at login** from the app's Settings when you want it to start with macOS. CC-Overlay deliberately does not install a Homebrew background service, so it has one app process and one login-start mechanism.

If you upgraded from `0.8.x`, remove its legacy Homebrew service once:

```bash
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/homebrew.mxcl.cc-overlay.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/homebrew.mxcl.cc-overlay.plist
brew upgrade cc-overlay
```

### Uninstall

Turn off **Launch at login** in Settings first, then remove the app:

```bash
brew uninstall cc-overlay
```

### Build from source

Requires **Swift 6.0+** and **macOS 15+** (Sequoia) SDK.

```bash
git clone https://github.com/jadru/homebrew-cc-overlay.git
cd homebrew-cc-overlay
./script/build_and_run.sh
```

To exercise the same universal packaging checks used by CI without notarization:

```bash
VERSION=0.0.0 BUILD_NUMBER=0 SIGN_IDENTITY=- NOTARIZE=0 ARCHS="arm64 x86_64" ./script/package_release.sh
```

## Usage

Run `cc-overlay` — the app lives in the menu bar. Click the menu bar icon to see detailed usage or open Settings.

### Data sources

| Source | Provider | How it works |
|--------|----------|-------------|
| **Anthropic OAuth** | Claude Code | Claude Code Keychain credentials — live 5-hour and 7-day buckets |
| **Codex OAuth** | Codex CLI | ChatGPT login stored by Codex in `~/.codex/auth.json` |
| **Local JSONL** | Claude Code | `~/.claude/projects/*/*.jsonl` fallback — clearly marked token-based estimate |

## Privacy and Provider Access

CC-Overlay has no developer-operated backend and does not upload usage history or OAuth credentials to the project maintainer. It makes outbound requests only to the selected provider's usage endpoint and to GitHub Releases when update checks are enabled.

- Codex usage reads the local Codex CLI authentication file to make a direct request to the provider's usage endpoint.
- Claude transcript estimates read recent local JSONL files. Claude OAuth rate-limit access is off by default and requires an explicit Settings opt-in.
- Usage history, settings, and diagnostic logs stay on the local Mac.

Provider tokens are sensitive. Review the source and use a release you trust before enabling a provider. This project is an unofficial integration and provider APIs, limits, and authentication formats may change without notice.

### Menu bar dropdown

The dropdown shows the selected provider's usage timeline. When both providers have
data, a compact provider switcher is shown above it. Each primary window presents
used and remaining capacity, reset timing, and a pace assessment.

### Floating pill

The overlay shows the most constrained provider. It stays inside the active screen
when expanded and shows 5H/7D pace meters. A local estimate is prefixed with `~`.

## Configuration

All settings persist via `UserDefaults` and are accessible from the Settings window (menu bar > Settings).

| Setting | Default | Description |
|---------|---------|-------------|
| Show overlay | On | Toggle floating pill |
| Always expanded | Off | Keep pill expanded without hover |
| Click-through | Off | Mouse events pass through overlay |
| Global hotkey | On | `Cmd+Shift+A` to toggle overlay |
| Cost alerts | On | Notify at 70%/90% usage |
| Plan tier | Pro | For local JSONL mode (Pro/Max/Enterprise/Custom) |
| Claude OAuth rate limits | Off | Read Claude Keychain credentials only after explicit opt-in |
| Refresh interval | 1 min | How often usage data is refreshed |
| Launch at login | Off | Start with macOS |

### Model pricing

Cost estimates use the following per-MTok rates:

| Model | Input | Output | Cache Write | Cache Read |
|-------|------:|-------:|------------:|-----------:|
| Fable 5 | $10 | $50 | $12.50 | $1.00 |
| Opus 4.5-4.8 | $5 | $25 | $6.25 | $0.50 |
| Opus 4.0/4.1 | $15 | $75 | $18.75 | $1.50 |
| Sonnet 5 / 4.x | $3 | $15 | $3.75 | $0.30 |
| Haiku 4.5 | $1 | $5 | $1.25 | $0.10 |
| Haiku 3.5 | $0.80 | $4 | $1.00 | $0.08 |

## License

[MIT](LICENSE)

Provider names and marks are the property of their respective owners. Their use here is solely to identify compatible tools.
