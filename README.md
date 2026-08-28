# CC-Overlay

> [한국어](README_KO.md) · [Release notes](RELEASE_NOTES.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

**A local-first macOS capacity overlay for Codex and Claude Code work.**

CC-Overlay keeps the Mac resources that affect an intensive coding run in one small surface: CPU, memory pressure and swap, network traffic, free storage, power, thermal state, and Codex or Claude Code rate-limit headroom. It is an independent open-source utility, not affiliated with Anthropic or OpenAI.

## What it shows

- A compact, always-available bar with CPU, RAM, network, SSD free space, and the most constrained available AI provider.
- Click any compact-bar metric for a focused detail popover. The trailing dashboard button opens an on-demand panel with 60 minutes of CPU and memory trends, a seven-day AI headroom graph, top accessible processes, storage, battery when present, and thermal state.
- Codex and Claude Code usage windows, reset timing, and pace information when each provider is locally configured.

System samples refresh every two seconds, or every five seconds in Low Power Mode. The app retains only the latest 60 minutes in memory; it does not persist or transmit system metrics.

## Display and alerts

The default is a compact overlay in every app. Settings also provides a **Developer tools only** mode. Click a metric for its details, or use the trailing dashboard button for the full view. The existing shortcut, `Cmd+Shift+A`, toggles the overlay. Screen-bound dragging, click-through, full-screen support, and Reduce Motion support are preserved.

If you choose **Hide Overlay** from the context menu, CC-Overlay appears in the Dock with **Overlay → Show Overlay** available for recovery. Showing the overlay again returns the app to its usual accessory mode.

macOS alerts are limited to configured AI-usage thresholds, elevated or critical memory pressure, and serious or critical thermal state. A repeated state does not notify again until the Mac has returned to normal.

## Install

```bash
brew tap jadru/cc-overlay
brew install cc-overlay
cc-overlay
```

Enable **Launch at login** in Settings when you want it to start with macOS. CC-Overlay deliberately does not install a Homebrew background service.

To remove it, disable Launch at login and run:

```bash
brew uninstall cc-overlay
```

## Build and verify

Requires Swift 6.0+ and the macOS 15+ SDK.

```bash
git clone https://github.com/jadru/homebrew-cc-overlay.git
cd homebrew-cc-overlay
./script/build_and_run.sh
swift test
```

Run the universal packaging checks without notarization:

```bash
VERSION=0.0.0 BUILD_NUMBER=0 SIGN_IDENTITY=- NOTARIZE=0 ARCHS="arm64 x86_64" ./script/package_release.sh
```

Tagged releases are signed, notarized universal app bundles. Verify a Homebrew installation with:

```bash
APP="$(brew --prefix cc-overlay)/CC-Overlay.app"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
```

## Data and privacy

| Data | Purpose | Storage |
|---|---|---|
| CPU, memory, network, storage, power, thermal state | Local system capacity display | Latest 60 minutes in memory only |
| Codex OAuth, app-server metadata, and recent rollout token counters | Codex headroom, reset details, and token fallback | Credentials remain in Codex/macOS storage; token counters are processed in memory |
| Claude OAuth or local JSONL | Claude Code headroom | Local processing; OAuth access requires opt-in |
| Provider usage history and preferences | Existing usage features and app configuration | Local Mac |

CC-Overlay has no developer-operated backend. It contacts provider-owned services only for requested usage metadata and GitHub Releases when automatic update checks are enabled. Review the source and use a release you trust before enabling a provider.

## Configuration

| Setting | Default | Description |
|---|---:|---|
| Overlay visibility | Every app | Every app or developer tools only |
| Show floating overlay | On | Shows or hides the floating system monitor |
| Click-through | Off | Passes pointer input to the app underneath |
| Global hotkey | On | Toggles the overlay with `Cmd+Shift+A` |
| Usage threshold alerts | On | Alerts at the configured provider-usage thresholds |
| Claude OAuth rate limits | Off | Reads Claude Keychain credentials only after explicit opt-in |
| Launch at login | Off | Starts CC-Overlay with macOS |

## License and feedback

[MIT](LICENSE). Use **Settings → Advanced → Share product feedback** or open a [feedback issue](https://github.com/jadru/homebrew-cc-overlay/issues/new?template=user_feedback.yml). Safe diagnostics exclude credentials, project names, usage history, and local paths.
