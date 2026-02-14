# CC-Overlay

**Claude Code**와 **Codex CLI** 사용량을 실시간으로 모니터링하는 macOS 메뉴바 앱.

> [English](README.md)

<!-- TODO: 스크린샷 -->

## 주요 기능

- **멀티 프로바이더 모니터링** — Claude Code와 OpenAI Codex CLI 사용량 동시 추적
- **자동 CLI 감지** — 설치된 CLI 및 인증 정보 자동 감지; 사용 가능한 것만 표시
- **실시간 사용량 추적** — Anthropic/OpenAI API 또는 로컬 JSONL 로그 기반 5시간/주간 rate limit 사용률
- **플로팅 오버레이 필** — 항상 최상단에 표시되는 glassmorphism 위젯; 호버 시 상세 정보 확장
- **프로바이더 탭 사이드바** — 메뉴바 드롭다운에서 프로바이더 간 전환
- **Enterprise 할당량 지원** — 3단계 지출 한도 표시 (개인 시트 / 시트 티어 / 조직)
- **Codex 크레딧 표시** — 플랜 유형, 크레딧 잔액, rate window 상세 분석
- **메뉴바 인디케이터** — 파이 차트, 바 차트, 퍼센트 표시 중 선택 가능
- **토큰 비용 분석** — 모델별 input, output, cache-write, cache-read 비용 계산
- **활성 세션 모니터링** — 실행 중인 Claude Code 세션 및 부모 앱 감지 (VS Code, Cursor, Terminal 등)
- **비용 임계값 알림** — 70%, 90% 사용 시 macOS 알림
- **글로벌 단축키** — `Cmd+Shift+A`로 오버레이 토글

## 설치

### Homebrew

```bash
brew tap jadru/cc-overlay
brew install cc-overlay
brew services start cc-overlay
```

### 소스에서 빌드

**Swift 6.0+** 및 **macOS 15+** (Sequoia) SDK 필요.

```bash
git clone https://github.com/jadru/cc-overlay.git
cd cc-overlay
swift build -c release
cp .build/release/cc-overlay /usr/local/bin/
```

## 사용법

`cc-overlay` 실행 — 메뉴바에 아이콘이 나타납니다. 클릭하면 상세 사용량 확인 및 설정 접근이 가능합니다.

### 데이터 소스

| 소스 | 프로바이더 | 동작 방식 |
|------|-----------|----------|
| **Anthropic API** | Claude Code | `~/.claude/credentials.json`의 OAuth 토큰 — 실시간 5시간/주간 버킷, Enterprise 할당량 |
| **OpenAI API** | Codex CLI | OAuth 또는 API 키 — 일별/주별 rate limit, 크레딧 잔액 |
| **로컬 JSONL** | Claude Code | `~/.claude/projects/**/usage.jsonl` 폴백 — 로그 기반 토큰 수 추정 |

### 메뉴바 드롭다운

드롭다운 패널은 **프로바이더 탭 사이드바** (복수 프로바이더 감지 시)와 프로바이더별 뷰를 표시합니다:

- **게이지 카드** — 잔여 퍼센트를 보여주는 원형 프로그레스
- **Enterprise 할당량 카드** — 개인/티어/조직 지출 한도 (Claude Code Enterprise 전용)
- **크레딧 카드** — 플랜 유형 및 크레딧 잔액 (Codex 전용)
- **비용 카드** — 5시간 및 일일 비용 추정
- **토큰 분석** — 타입별 가중치 적용 토큰 사용량
- **Rate limit 필** — 5h / 7d / Sonnet 버킷 사용률 (Claude Code) 또는 일별/주별 윈도우 (Codex)

### 플로팅 필

오버레이 필은 **가장 긴급한 프로바이더** (한도에 가장 근접)의 잔여 퍼센트를 간결하게 표시하며, 호버 시 다음 정보로 확장됩니다:

- 5시간 비용이 표시된 원형 게이지
- Rate limit 사용률 필
- Enterprise 시트 잔여 금액 (해당 시)
- 일일 비용 (선택적)

## 설정

모든 설정은 `UserDefaults`에 저장되며 설정 창(메뉴바 > Settings)에서 접근할 수 있습니다.

| 설정 | 기본값 | 설명 |
|------|--------|------|
| Show overlay | On | 플로팅 필 표시/숨기기 |
| Always expanded | Off | 호버 없이 항상 확장 상태 유지 |
| Show daily cost | Off | 확장 필에 일일 비용 표시 |
| Opacity | 100% | 오버레이 불투명도 (50-100%) |
| Click-through | Off | 오버레이를 투과하여 뒤 콘텐츠 클릭 |
| Menu bar indicator | Pie Chart | 파이 차트, 바 차트, 퍼센트 중 선택 |
| Global hotkey | On | `Cmd+Shift+A`로 오버레이 토글 |
| Cost alerts | On | 70%/90% 사용 시 알림 |
| Plan tier | Pro | 로컬 JSONL 모드용 (Pro/Max/Enterprise/Custom) |
| Refresh interval | 1분 | 사용량 데이터 갱신 주기 |
| Launch at login | Off | macOS 시작 시 자동 실행 |
| Claude Code enabled | On | Claude Code 사용량 모니터링 |
| Codex enabled | On | Codex CLI 사용량 모니터링 |
| Codex API key | — | Codex용 수동 API 키 (OAuth 미사용 시) |

### 모델별 가격

비용 추정에 사용되는 MTok당 요금:

| 모델 | Input | Output | Cache Write | Cache Read |
|------|------:|-------:|------------:|-----------:|
| Opus 4.5/4.6 | $5 | $25 | $6.25 | $0.50 |
| Opus 4.0/4.1 | $15 | $75 | $18.75 | $1.50 |
| Sonnet 4.x | $3 | $15 | $3.75 | $0.30 |
| Haiku 4.5 | $1 | $5 | $1.25 | $0.10 |
| Haiku 3.5 | $0.80 | $4 | $1.00 | $0.08 |

## 라이선스

[MIT](LICENSE)
