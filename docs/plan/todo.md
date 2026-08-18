# CC Overlay Plan TODO (미진행/잔여)

기준 문서: `.context/attachments/plan.md`

## Quick Wins 잔여

### 1) `fatalError` 제거 — 완료
- `BaseProviderService`는 lifecycle/backoff만 담당하고, 구체 provider가
  `ProviderServiceProtocol`을 명시적으로 준수해 `fetchUsage()`를 구현하도록 변경됨.

### 6) VoiceOver 접근성 전수 점검
- 현재 상태: `MenuBarLabel`, `PillView`, refresh 버튼 외에 provider 오류 배지와
  detail sheet 닫기 버튼의 명시적 접근성 문구를 추가함. provider 전환은 숫자키,
  `R`, 방향키로도 가능.
- 남은 작업: 실제 VoiceOver 사용자가 전체 카드/배지/상태 아이콘을 수동 검증하고
  누락 라벨·값·힌트를 보강.
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
- Codex-first 안전 라우팅과 Codex app-server 기반 Full Reset 만료 인식
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
- 완료: 로컬 Claude transcript 항목이 있을 때 menu bar overflow에
  **Export local usage CSV**를 노출. 사용자 제스처로만 저장 패널을 엶.

## Nice to Have 미진행

### 9) Provider별 인라인 에러 표시
- 완료: provider summary 카드에 경고 배지를 표시하고 VoiceOver 값에
  refresh 실패 내용을 포함.

### 10) 키보드 네비게이션
- 완료: 방향키와 `1`/`2`/`3`으로 provider 전환, `R`로 새로고침.

### 11) 모델별 토큰 추적
- 모델별 사용량 비중 분석/표시

### 12) Dark/Light 글래스모피즘 최적화
- `colorScheme` 기반 opacity/contrast 튜닝

### 13) Provider 빠른 일시중지
- 컨텍스트 메뉴 `Pause Monitoring`

### 14) 세션 지속시간 표시
- `SessionMonitor` UI 연결
