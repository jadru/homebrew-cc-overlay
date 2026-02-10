# CC-Overlay

> [한국어](README_KO.md) | [Release Notes](RELEASE_NOTES.md) ([한국어](RELEASE_NOTES_KO.md))

macOS menu bar app that monitors your Claude Code usage in real time.

<!-- TODO: screenshot -->

## Features

- **Real-time usage tracking** — 5-hour and weekly rate limit utilization from Anthropic API or local JSONL logs
- **Floating overlay pill** — Always-on-top glassmorphism widget; expands on hover for detailed usage breakdown
- **Enterprise quota support** — 3-tier spending limit display (individual seat / seat tier / organization)
- **Menu bar indicators** — Pie chart, bar chart, or percentage style — configurable
- **Token cost breakdown** — Input, output, cache-write, cache-read with per-model pricing
- **Active session monitoring** — Detects running Claude Code sessions and their parent apps (VS Code, Cursor, Terminal, etc.)
- **Cost threshold alerts** — macOS notifications at 70% and 90% usage
- **Global hotkey** — Toggle overlay with `Cmd+Shift+A`

## Install

### Homebrew

```bash
brew tap jadru/cc-overlay
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
| **Anthropic API** | OAuth token from `~/.claude/credentials.json` — live 5-hour / weekly buckets, Enterprise quota |
| **Local JSONL** | Falls back to `~/.claude/projects/**/usage.jsonl` — estimated from logged token counts |

### Menu bar dropdown

The dropdown panel shows:

- **Gauge card** — Circular progress with remaining percentage
- **Enterprise quota card** — Individual/tier/org spending limits (Enterprise plans only)
- **Cost card** — 5-hour and daily cost estimates
- **Token breakdown** — Weighted token counts by type
- **Rate limit pills** — 5h / 7d / Sonnet bucket utilization

### Floating pill

The overlay pill shows a compact remaining percentage that expands on hover to reveal:

- Circular gauge with 5-hour cost
- Rate limit utilization pills
- Enterprise seat remaining (if applicable)
- Daily cost (optional)

## Configuration

All settings persist via `UserDefaults` and are accessible from the Settings window (menu bar > Settings).

| Setting | Default | Description |
|---------|---------|-------------|
| Show overlay | On | Toggle floating pill |
| Always expanded | Off | Keep pill expanded without hover |
| Show daily cost | Off | Show daily cost in expanded pill |
| Opacity | 100% | Overlay window opacity (50–100%) |
| Click-through | Off | Mouse events pass through overlay |
| Menu bar indicator | Pie Chart | Pie chart, bar chart, or percentage |
| Global hotkey | On | `Cmd+Shift+A` to toggle overlay |
| Cost alerts | On | Notify at 70%/90% usage |
| Plan tier | Pro | For local JSONL mode (Pro/Max/Enterprise/Custom) |
| Refresh interval | 1 min | How often usage data is refreshed |
| Launch at login | Off | Start with macOS |

### Model pricing

Cost estimates use the following per-MTok rates:

| Model | Input | Output | Cache Write | Cache Read |
|-------|------:|-------:|------------:|-----------:|
| Opus 4.5/4.6 | $5 | $25 | $6.25 | $0.50 |
| Opus 4.0/4.1 | $15 | $75 | $18.75 | $1.50 |
| Sonnet 4.x | $3 | $15 | $3.75 | $0.30 |
| Haiku 4.5 | $1 | $5 | $1.25 | $0.10 |
| Haiku 3.5 | $0.80 | $4 | $1.00 | $0.08 |

## License

[MIT](LICENSE)
