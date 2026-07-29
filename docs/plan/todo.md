# CC Overlay Plan TODO (미진행/잔여)

기준 문서: `.context/attachments/plan.md`

## Quick Wins 잔여

### 1) `fatalError` 제거 마무리
- 현재 상태: `ProviderServiceProtocol`에 `fetchUsage()` 요구사항은 추가됨
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

## 90일 실행 완료

- 신규 사용자 온보딩 및 기존 사용자 무중단 마이그레이션
- CLI 설치·로그인·stale·schema 변경을 구분하는 Activation Doctor와 복구 액션
- 프로바이더 상태를 종합한 Run / Wait / Switch 추천
- stale 차단, 신뢰도, 추천 안정화 및 작업 크기별 적합도 학습
- 활성 프로젝트에서 실제 CLI 실행/전환, 결과 기록, 설명 가능한 추천, Full Reset 정책
- 7일 로컬 히스토리, 소진 ETA, Provider Health Dashboard
- 서비스·네트워크·인증·데이터·UI 채널별 OSLog와 adaptive polling backoff
- `UNUserNotificationCenter` 기반 사용량/리셋 알림
- credential·프로젝트·경로·사용량 기록을 제외한 안전한 진단 복사
- 앱 내 버그 신고 및 제품/가격 피드백 진입점
- 랜딩 페이지, 전환 측정, 출시 키트, 90일 스코어카드, BM 검증 게이트

## Strategic 후속 후보

### 7) 프로젝트별 비용 분석
- `ParsedUsageEntry.projectPath` 보존
- 프로젝트별 비용 카드 추가

### 8) CSV 내보내기 UI
- 현재 상태: Copy Summary와 CSV 생성/저장 서비스는 구현됨
- 남은 작업: CSV export 진입점 노출

## Nice to Have 미진행

### 9) Provider별 인라인 에러 표시
- 탭 사이드바 경고 배지 추가

### 10) 키보드 네비게이션
- 방향키 provider 전환
- `R` 새로고침 단축

### 11) 모델별 토큰 추적
- 모델별 사용량 비중 분석/표시

### 12) Dark/Light 글래스모피즘 최적화
- `colorScheme` 기반 opacity/contrast 튜닝

### 13) Provider 빠른 일시중지
- 컨텍스트 메뉴 `Pause Monitoring`

### 14) 세션 지속시간 표시
- `SessionMonitor` UI 연결
