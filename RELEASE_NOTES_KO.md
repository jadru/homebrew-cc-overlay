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
