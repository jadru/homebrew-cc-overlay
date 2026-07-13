# v0.10.5

## 안정적인 릴리스 확인과 오버레이 이동

> [English](RELEASE_NOTES.md)

### 주요 변경

- **rate limit 없는 업데이트 확인** — 비인증 GitHub API 대신 latest release 리다이렉트로 버전을 확인합니다.
- **읽기 쉬운 긴 카운트다운** — 24시간 이상은 일·시간, 미만은 시간·분으로 표시합니다.
- **충돌 없는 오버레이 이동** — hover 확장을 지연해 즉시 press-drag 시 접힌 pill 크기 그대로 이동합니다.
- **안전한 입력 우선순위** — 확장된 컨트롤과 Start expanded 설정은 유지하고 이동 중 확장을 막습니다.

---

# v0.10.4

## 간결한 Codex 주간 레이아웃

> [English](RELEASE_NOTES.md)

### 주요 변경

- **콘텐츠 기반 패널 높이** — Codex에 주간 윈도우만 있을 때 메뉴 패널을 compact 높이로 표시합니다.
- **필요한 제한에 집중** — 사용하지 않는 Spark 제한은 숨기고 다른 보조 제한은 유지합니다.
- **반응형 밀도** — 5H와 7D 윈도우가 모두 있으면 기존 패널 높이를 유지합니다.

---

# v0.10.3

## 안정적인 인앱 업데이트

> [English](RELEASE_NOTES.md)

### 주요 변경

- **정확한 버전 확인** — 오래된 소스 메타데이터 대신 설치된 앱 번들의 실제 버전을 사용합니다.
- **업그레이드 검증** — 재시작을 안내하기 전에 Homebrew가 요청한 버전을 실제로 설치했는지 확인합니다.
- **안전한 재시작** — 설치 번들을 다시 검증하고 업데이트 실패를 메뉴바에 표시합니다.
- **asdf Codex 탐지** — asdf로 관리되는 Codex CLI 설치를 감지합니다.

---

# v0.10.0

## 신뢰할 수 있는 사용량, 네이티브 오버레이, 서명된 배포

> [English](RELEASE_NOTES.md)

### 주요 변경

- **신뢰 가능한 프로바이더 lifecycle** — 매 갱신 때 인증을 재검증하고, 인증이 해제된 프로바이더와 오래된 Codex snapshot을 제거합니다.
- **엄격한 사용량 파싱** — 잘못된 Claude OAuth payload를 정상적인 0% 사용량으로 표시하지 않고 실패로 처리합니다.
- **Codex 지원 집중** — 지원되지 않는 API-key billing 경로를 제거하고 Codex CLI의 ChatGPT OAuth 세션만 사용합니다.
- **추정값 투명성** — JSONL 폴백 데이터를 메뉴바와 오버레이에서 일관되게 표시합니다.
- **릴리즈 품질 강화** — CI가 배포 전 테스트, Formula 문법, 앱 메타데이터, 리소스, 서명, 공증, zip artifact를 검증합니다.

### 배포

- 릴리즈 archive는 provider icon을 포함한 완전한 `CC-Overlay.app`을 담고 Finder metadata side file을 제외합니다.
- Homebrew는 배포 서명을 덮어쓰지 않고 서명된 앱 번들을 설치합니다.

---

# v0.9.1

## 실행 안정성: macOS 15 Brew 복구, 더 안전한 시작, Codex GUI 오버레이

> [English](RELEASE_NOTES.md)

### 주요 변경

- **macOS 15 Homebrew 복구 가이드 추가** — `0.8.x`에서 업그레이드 후 예전 `opt_bin` LaunchAgent에 걸린 사용자를 위한 정리/재설치 절차 문서화
- **알림 초기화 안전성 개선** — `CostAlertManager`가 `UNUserNotificationCenter`를 지연 초기화하도록 바꿔 앱 시작 시점의 notification center 초기화 의존성을 제거
- **Codex GUI 오버레이 whitelist 보강** — Codex 데스크톱 helper 번들 ID도 허용해 Codex helper 프로세스가 포커스를 잡아도 플로팅 오버레이가 유지되도록 개선
- **회귀 테스트 추가** — notification center 지연 초기화와 Codex helper whitelist 동작을 검증하는 테스트 추가

### 릴리즈 메모

- 앱 번들 메타데이터의 버전 문자열을 실제 배포 버전인 `0.9.1`로 맞춰 기존의 stale `0.8.0` 값 문제를 정리
- 릴리즈 자동화(`.github/workflows/release.yml`)가 태그 푸시 시 macOS 아티팩트를 빌드/패키징하고 Homebrew formula를 tap과 동기화
- 이번 릴리즈 태그: `v0.9.1`

---

# v0.8.0

## 메뉴바 리프레시, 오버레이 내비게이션, 프로바이더 파싱 안정화

> [English](RELEASE_NOTES.md)

### 주요 변경

- **메뉴바 재설계** — 더 넓고 스크롤 가능한 패널, 정리된 프로바이더 헤더, 빠른 액션 클러스터, 개선된 빈 상태 안내 추가
- **프로바이더 요약 카드** — Claude Code와 Codex를 빠르게 비교할 수 있는 compact/standard 요약 카드 추가
- **오버레이 상세 탐색** — 확장 pill에서 프로바이더 선택, pin 고정, 세션 리셋/최근 활동 정보, stale 상태 표시 개선
- **Settings 정리** — 설정을 더 명확한 섹션으로 재구성하고, 고급 인증 정보와 fallback 튜닝은 disclosure로 분리
- **Claude OAuth 파싱 강화** — 중첩 payload 형태 지원, 잘못된 응답의 안전한 zero-bucket 처리, 플랜 식별자 정규화, Keychain access denied 대응 추가
- **한도 표시 정규화 개선** — Claude fallback 추정이 감지된 플랜 티어와 세션 소진 예측을 사용하고, Codex 게이지는 가장 제한적인 window를 기준으로 더 읽기 쉬운 라벨을 표시
- **회귀 테스트 추가** — OAuth 응답 파서와 프로바이더 사용량 정규화에 대한 집중 테스트 추가

### Brew 릴리즈 메모

- 릴리즈 자동화(`.github/workflows/release.yml`)가 태그 기준으로 Homebrew formula URL/SHA를 갱신하고 tap 저장소와 동기화
- 이번 릴리즈 태그: `v0.8.0`

---

# v0.7.0

## Quick Wins: 안정성, 보안, 접근성

> [English](RELEASE_NOTES.md)

### 주요 변경

- **프로바이더 아키텍처 안정화** — `fetchUsage()`를 프로토콜 요구사항으로 명시
- **비용 예산 설정 노출** — Settings에 Claude 플랜 티어 선택 + custom weighted limit 입력 추가
- **Stale 데이터 표시기** — 데이터가 `refresh interval`의 2배 이상 오래되면 메뉴바/오버레이에 경고 표시
- **알림 임계값 커스터마이즈** — Warning/Critical 임계값을 Settings에서 조절하고 알림 로직에 반영
- **API 키 보안 마이그레이션** — Codex 수동 API 키를 UserDefaults에서 Keychain으로 이전(기존 값 자동 마이그레이션)
- **VoiceOver 접근성 개선** — 메뉴바 상태, 오버레이 상태, 새로고침 액션에 접근성 라벨/값 추가

### Brew 릴리즈 메모

- 릴리즈 자동화(`.github/workflows/release.yml`)가 태그 기준으로 Homebrew formula URL/SHA를 갱신하고 tap 저장소와 동기화
- 이번 릴리즈 태그: `v0.7.0`

---

# v0.6.0

## Homebrew OTA 자동 업데이트

> [English](RELEASE_NOTES.md)

### 신규 기능

- **자동 업데이트 체크** — 앱 시작 시 (3초 딜레이) + 24시간마다 GitHub Releases API를 통해 새 버전 확인
- **메뉴바 업데이트 뱃지** — 업데이트 가능 시 메뉴바 아이콘에 파란 점 표시
- **업데이트 배너** — 메뉴바 드롭다운에 상태별 인앱 배너:
  - **업데이트 가능** (파란색) — 새 버전 표시 + "Update Now" / 닫기 버튼
  - **설치 중** — `brew update && brew upgrade` 실행 중 프로그레스 표시
  - **재시작 대기** (초록색) — 설치 완료 후 "Restart Now" / "Later" 버튼
- **Settings > Updates 섹션** — 자동 업데이트 토글, 현재 버전, 마지막 체크 시간, 수동 "Check for Updates" 버튼 및 실시간 상태 표시
- **CI 버전 자동 주입** — 릴리스 워크플로우에서 git 태그 기반으로 소스코드 버전 자동 주입 후 빌드

### 내부 변경

- `AppConstants.version`, `AppConstants.githubRepo`, `AppConstants.updateCheckInterval` 상수 추가
- `AppSettings.autoUpdateEnabled` (Bool) 및 `AppSettings.lastUpdateCheck` (Date?) UserDefaults 지원 추가
- `UpdateService` 신규 추가 (`@Observable @MainActor`) — GitHub API 체크, 시맨틱 버전 비교, `/bin/bash -l -c`로 brew 업데이트/업그레이드, `brew services restart`로 재시작
- `UpdateBannerView` 신규 추가 — `ErrorBannerView`의 glass-effect 패턴을 파란색/초록색 틴트로 적용
- `MenuBarLabel`, `MenuBarView`, `SettingsView`, `CCOverlayApp`, `AppDelegate`, `WindowCoordinator`에 `UpdateService` 연결
- `.github/workflows/release.yml`에 "Inject version" 스텝 추가

### 변경된 파일

- 수정: 10개 파일
- 추가: 2개 파일

---

# v0.5.0

## 멀티 프로바이더: Codex CLI 지원

> [English](RELEASE_NOTES.md)

### 신규 기능

- **멀티 프로바이더 아키텍처** — CC-Overlay가 **Claude Code**와 **OpenAI Codex CLI** 사용량을 동시에 모니터링
- **자동 CLI 감지** — 설치된 CLI 자동 감지 (Claude Code: `~/.claude`, Codex: Homebrew/npm/`~/.local/bin`) 및 OAuth 인증 정보
- **Codex CLI 통합** — OpenAI API를 통한 실시간 사용량 모니터링: rate limit, 크레딧 잔액, 비용 추정
- **프로바이더 탭 사이드바** — 메뉴바 드롭다운에서 Claude Code와 Codex 뷰 전환
- **프로바이더 뱃지** — 각 프로바이더 상태 시각적 표시 (활성, 비활성, 경고)
- **Codex 크레딧 카드** — 플랜 유형, 크레딧 잔액, 추가 사용 상태 표시
- **Codex rate window 카드** — 일별/주별 rate limit 상세 분석 및 리셋 타이머
- **프로바이더별 설정** — 각 프로바이더 개별 활성화/비활성화; Codex API 키 수동 입력 지원

### 개선 사항

- **정규화된 사용량 모델** — `ProviderUsageData`로 모든 CLI 프로바이더에 대한 통합 데이터 구조 제공
- **Critical 프로바이더 추적** — 플로팅 필과 메뉴바가 자동으로 한도에 가장 가까운 프로바이더를 표시
- **하위 호환성** — 기존 Claude Code 단독 사용자는 UI 변경 없음; Codex 기능은 감지 시에만 표시

### 내부 변경

- `CLIProvider` enum (`.claudeCode`, `.codex`) 및 `BillingMode` enum 추가
- `ProviderUsageData`, `RateBucket`, `CostSummary`, `CreditsDisplayInfo`, `DetailedRateWindow` 모델 추가
- `MultiProviderUsageService` 코디네이터 신규 추가 (프로바이더별 서비스 관리)
- `ClaudeCodeProviderService` 신규 추가 (기존 `UsageDataService` 래핑)
- Codex 서비스 레이어: `CodexDetector`, `CodexOAuthService`, `CodexProviderService`, `OpenAIAPIService`, `OpenAICostCalculator`
- 신규 UI 컴포넌트: `ProviderTabSidebar`, `ProviderBadge`, `ProviderSectionView`, `CreditsInfoCardView`, `RateWindowsCardView`
- `cc-overlay.entitlements` 추가 (네트워크 클라이언트 권한)
- 소스 트리에서 번들된 `CC-Overlay.app` 바이너리 제거

### 변경된 파일

- 수정: 17개 파일
- 추가: 10개 파일
- 삭제: 2개 파일
