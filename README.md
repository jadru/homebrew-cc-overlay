# CC-Overlay

macOS menu bar app that monitors your Claude Code usage in real time.

<!-- TODO: screenshot -->

## Features

- **Real-time usage tracking** — 5-hour and weekly rate limit utilization from Anthropic API or local JSONL logs
- **Floating overlay pill** — Always-on-top glassmorphism widget showing usage at a glance; expands on hover for details
- **Model distribution bar** — Visual breakdown of Opus / Sonnet / Haiku token usage
- **Active session monitoring** — Detects running Claude Code sessions and their parent apps (VS Code, Cursor, Terminal, etc.)
- **Cost threshold alerts** — macOS notifications at 70% and 90% usage
- **Smart auto-hide** — Overlay only appears when developer tools (IDEs, terminals, Claude) are focused
- **Global hotkey** — Toggle overlay with `Cmd+Shift+A`
- **Settings preview** — Display settings changes are shown live on the overlay for 5 seconds

## Install

### Homebrew

```bash
brew tap jadru/tap
brew install cc-overlay
brew services start cc-overlay
```

### Build from source

Requires **Swift 6.2** and **macOS 26** (Tahoe) SDK.

```bash
git clone https://github.com/jadru/cc-overlay.git
cd cc-overlay
swift build -c release
cp .build/release/cc-overlay /usr/local/bin/
```

## Usage

Run `cc-overlay` — the app lives in the menu bar. Click the menu bar icon to see detailed usage or open Settings.

### Data sources

| Source | How it works |
|--------|-------------|
| **Anthropic API** | OAuth token from `~/.claude/credentials.json` — live 5-hour / weekly buckets |
| **Local JSONL** | Falls back to `~/.claude/projects/**/usage.jsonl` — estimated from logged token counts |

### Overlay positions

Top-right (default), top-left, bottom-right, bottom-left — configurable in Settings.

## Configuration

All settings persist via `UserDefaults` and are accessible from the Settings window (`Cmd+,` or menu bar > Settings).

| Setting | Default | Description |
|---------|---------|-------------|
| Show overlay | On | Toggle floating pill |
| Overlay position | Top-right | Screen corner |
| Click-through | Off | Mouse events pass through overlay |
| Opacity | 100% | Overlay window opacity |
| Glass intensity | 15% | Background blur tint strength |
| Only show with dev tools | On | Auto-hide when non-dev apps are focused |
| Global hotkey | On | `Cmd+Shift+A` to toggle overlay |
| Session monitoring | On | Detect active Claude Code processes |
| Cost alerts | On | Notify at 70%/90% usage |
| Refresh interval | 30s | How often usage data is refreshed |
| Launch at login | Off | Start with macOS |

## License

[MIT](LICENSE)
