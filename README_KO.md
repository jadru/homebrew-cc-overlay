# CC-Overlay

**Claude Code**와 **Codex CLI** 사용량을 실시간으로 모니터링하는 macOS 메뉴바 앱.

CC-Overlay는 GitHub Releases와 Homebrew로 직접 배포하는 독립 오픈소스 유틸리티입니다. Anthropic이나 OpenAI와 제휴, 보증 또는 지원 관계가 아닙니다.

> [English](README.md) | [릴리스 노트](RELEASE_NOTES_KO.md) | [기여](CONTRIBUTING.md) | [보안](SECURITY.md)

## 주요 기능

- **멀티 프로바이더 모니터링** — Claude Code와 OpenAI Codex CLI 사용량 동시 추적
- **인증된 프로바이더만 표시** — 설정되지 않은 프로바이더를 setup/사용량 지표로 잘못 노출하지 않음
- **실시간 rate-limit 윈도우** — Claude Code와 Codex OAuth의 5시간·7일 한도 표시
- **명확한 로컬 폴백** — Claude JSONL 추정값에는 `~`와 "local estimate"를 표시
- **플로팅 Liquid Glass 오버레이** — 화면 경계를 넘지 않고 호버 시 확장되는 상태 surface
- **페이스 신호** — 5H·7D 타임라인에서 빠른 소진, 정상 페이스, 여유 상태를 구분
- **조건부 프로바이더 전환** — 두 프로바이더 모두 사용량이 있을 때만 compact selector 표시
- **비용 임계값 알림** — 70%, 90% 사용 시 macOS 알림
- **글로벌 단축키** — `Cmd+Shift+A`로 오버레이 토글

## 배포 및 신뢰

태그 릴리스는 Apple Silicon과 Intel을 모두 지원하는 universal app bundle로 빌드됩니다. Developer ID Application 인증서와 hardened runtime으로 서명하고, Apple notarization 및 stapling을 거쳐 공개합니다. 릴리스 workflow는 앱 서명, 번들 구성, 깨끗한 archive, SHA-256 checksum도 검증합니다.

Homebrew는 서명된 `CC-Overlay.app` bundle을 다시 서명하지 않고 설치합니다. 설치된 릴리스는 아래처럼 검증할 수 있습니다.

```bash
APP="$(brew --prefix cc-overlay)/CC-Overlay.app"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
```

GitHub Release archive를 직접 받았다면, 열기 전에 공개된 checksum을 확인합니다.

```bash
shasum -a 256 -c CC-Overlay-vX.Y.Z-macos.zip.sha256
```

`script/build_and_run.sh`로 만든 로컬 빌드는 개발용 ad-hoc 서명입니다. 배포용 릴리스 artifact가 아닙니다.

## 설치

### Homebrew

```bash
brew tap jadru/cc-overlay
brew install cc-overlay
cc-overlay
```

macOS 시작 시 자동 실행하려면 앱 설정에서 **Launch at login**을 켭니다. CC-Overlay는 Homebrew 백그라운드 서비스를 설치하지 않으므로 앱 프로세스와 로그인 시작 경로가 각각 하나만 유지됩니다.

`0.8.x`에서 업그레이드했다면 기존 Homebrew 서비스를 한 번 정리하세요.

```bash
brew services stop cc-overlay
rm -f ~/Library/LaunchAgents/homebrew.mxcl.cc-overlay.plist
brew upgrade cc-overlay
```

### 제거

먼저 설정에서 **Launch at login**을 끈 뒤 앱을 제거합니다.

```bash
brew uninstall cc-overlay
```

### 소스에서 빌드

**Swift 6.0+** 및 **macOS 15+** (Sequoia) SDK 필요.

```bash
git clone https://github.com/jadru/homebrew-cc-overlay.git
cd homebrew-cc-overlay
./script/build_and_run.sh
```

notarization 없이 CI와 같은 universal packaging 검사를 실행하려면 다음을 사용합니다.

```bash
VERSION=0.0.0 BUILD_NUMBER=0 SIGN_IDENTITY=- NOTARIZE=0 ARCHS="arm64 x86_64" ./script/package_release.sh
```

## 사용법

`cc-overlay` 실행 — 메뉴바에 아이콘이 나타납니다. 클릭하면 상세 사용량 확인 및 설정 접근이 가능합니다.

### 데이터 소스

| 소스 | 프로바이더 | 동작 방식 |
|------|-----------|----------|
| **Anthropic OAuth** | Claude Code | Claude Code Keychain 인증 정보 — 실시간 5시간·7일 버킷 |
| **Codex OAuth** | Codex CLI | Codex가 `~/.codex/auth.json`에 저장한 ChatGPT 로그인 |
| **로컬 JSONL** | Claude Code | `~/.claude/projects/*/*.jsonl` 폴백 — 로그 기반 추정값임을 명시 |

## 개인정보 및 프로바이더 접근

CC-Overlay는 개발자가 운영하는 backend를 두지 않으며, 사용량 기록이나 OAuth credential을 프로젝트 유지보수자에게 업로드하지 않습니다. 선택한 provider의 usage endpoint와, 업데이트 확인을 켠 경우 GitHub Releases에만 outbound request를 보냅니다.

- Codex 사용량은 로컬 Codex CLI 인증 파일을 읽고 provider usage endpoint에 직접 요청합니다.
- Claude transcript 추정은 최근 로컬 JSONL 파일을 읽습니다. Claude OAuth rate limit 접근은 기본적으로 꺼져 있으며 Settings에서 명시적으로 켤 때만 시도합니다.
- 사용량 기록, 설정, diagnostic log는 로컬 Mac에 저장됩니다.

provider token은 민감한 정보입니다. provider를 활성화하기 전에 소스를 검토하고 신뢰할 수 있는 릴리스만 사용하세요. 이 프로젝트는 비공식 integration이며 provider API, 한도, 인증 형식은 예고 없이 변경될 수 있습니다.

### 메뉴바 드롭다운

드롭다운은 선택한 프로바이더의 사용량 타임라인을 보여줍니다. 두 프로바이더
모두 사용량이 있을 때만 상단에 compact selector가 표시됩니다. 각 윈도우에는
사용량·잔여량·리셋 시각·현재 페이스가 함께 표시됩니다.

### 플로팅 필

오버레이는 가장 제한적인 프로바이더를 표시합니다. 확장해도 현재 화면 경계를
넘지 않으며, 5H/7D 페이스 미터를 보여줍니다. 로컬 추정값은 `~`로 구분됩니다.

## 설정

모든 설정은 `UserDefaults`에 저장되며 설정 창(메뉴바 > Settings)에서 접근할 수 있습니다.

| 설정 | 기본값 | 설명 |
|------|--------|------|
| Show overlay | On | 플로팅 필 표시/숨기기 |
| Always expanded | Off | 호버 없이 항상 확장 상태 유지 |
| Click-through | Off | 오버레이를 투과하여 뒤 콘텐츠 클릭 |
| Global hotkey | On | `Cmd+Shift+A`로 오버레이 토글 |
| Cost alerts | On | 70%/90% 사용 시 알림 |
| Plan tier | Pro | 로컬 JSONL 모드용 (Pro/Max/Enterprise/Custom) |
| Claude OAuth rate limits | Off | 명시적으로 켠 경우에만 Claude Keychain credential 읽기 |
| Refresh interval | 1분 | 사용량 데이터 갱신 주기 |
| Launch at login | Off | macOS 시작 시 자동 실행 |

### 모델별 가격

비용 추정에 사용되는 MTok당 요금:

| 모델 | Input | Output | Cache Write | Cache Read |
|------|------:|-------:|------------:|-----------:|
| Fable 5 | $10 | $50 | $12.50 | $1.00 |
| Opus 4.5-4.8 | $5 | $25 | $6.25 | $0.50 |
| Opus 4.0/4.1 | $15 | $75 | $18.75 | $1.50 |
| Sonnet 5 / 4.x | $3 | $15 | $3.75 | $0.30 |
| Haiku 4.5 | $1 | $5 | $1.25 | $0.10 |
| Haiku 3.5 | $0.80 | $4 | $1.00 | $0.08 |

## 라이선스

[MIT](LICENSE)

provider 이름과 mark는 각 권리자의 자산입니다. 여기서는 호환 도구를 식별하는 용도로만 사용합니다.
