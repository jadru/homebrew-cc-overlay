# CC Overlay Plan TODO (미진행/잔여)

기준 문서: `.context/attachments/plan.md`

## Quick Wins 잔여

### 1) `fatalError` 제거 마무리
- 현재 상태: `ProviderServiceProtocol`에 `fetchUsage()`는 추가됨, `fatalError`는 제거됨
- 남은 작업: `BaseProviderService`의 기본 `fetchUsage()` 구현 자체 제거(프로토콜 요구를 서브클래스에서 강제)
- 대상 파일:
  - `Sources/CCOverlay/Services/BaseProviderService.swift`
  - `Sources/CCOverlay/Services/ProviderServiceProtocol.swift`

### 6) VoiceOver 접근성 전수 점검
- 현재 상태: `MenuBarLabel`, `PillView`, refresh 버튼 접근성은 추가됨
- 남은 작업: 카드/배지/상태 아이콘 등 시각 요소 전수 점검 후 누락 라벨/값/힌트 보강
- 대상 파일:
  - `Sources/CCOverlay/Views/MenuBar/*.swift`
  - `Sources/CCOverlay/Views/Panels/Content/*.swift`
  - `Sources/CCOverlay/Views/Components/*.swift`

## Strategic 미진행

### 7) OSLog 통합
- `Utilities/AppLogger.swift` 추가
- 서비스/네트워크/인증/데이터/UI 로거 채널 분리

### 8) Intelligent Polling Backoff
- idle 시 polling 4배(최대 5분)로 완화
- `lastActivityAt` 기반 adaptive interval 적용

### 9) 사용량 히스토리 & 트렌드
- SwiftData 기반 usage snapshot 저장소
- 스파크라인(Charts) UI 추가

### 10) Rate Limit 소진 예측
- 최근 사용량 기울기 기반 ETA 계산
- Gauge/Pill에 `~Xh Ym to limit` 노출

### 11) 프로젝트별 비용 분석
- `ParsedUsageEntry.projectPath` 보존
- 프로젝트별 비용 카드 추가

### 12) 사용량 복사/내보내기
- Copy Summary(마크다운)
- CSV export

## Nice to Have 미진행

### 13) Provider별 인라인 에러 표시
- 탭 사이드바 경고 배지 추가

### 14) 키보드 네비게이션
- 방향키 provider 전환
- `R` 새로고침 단축

### 15) `NSUserNotification` → `UNUserNotificationCenter`
- deprecated 알림 API 교체

### 16) 모델별 토큰 추적
- 모델별 사용량 비중 분석/표시

### 17) Dark/Light 글래스모피즘 최적화
- `colorScheme` 기반 opacity/contrast 튜닝

### 18) Provider 빠른 일시중지
- 컨텍스트 메뉴 `Pause Monitoring`

### 19) 세션 지속시간 표시
- `SessionMonitor` UI 연결

### 20) Provider Health Dashboard
- 인증 상태/마지막 성공 시각/응답 지연 통합 뷰
