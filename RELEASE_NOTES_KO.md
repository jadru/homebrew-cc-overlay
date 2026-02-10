# v0.2.0

## Enterprise 할당량 및 가격 업데이트

> [English](RELEASE_NOTES.md)

### 신규 기능

- **Enterprise 플랜 할당량 표시** — Enterprise 구독 감지 시 3단계 지출 한도를 시각적으로 표시:
  - **개인 시트** 한도 (주요 표시, 강조)
  - **시트 티어** 한도 (Standard / Premium 티어 합산)
  - **조직** 한도 (전체 조직 합산)
  - 각 한도별 사용/잔여 금액, 색상 코딩된 사용률, 리셋 카운트다운 제공
- **Enterprise 할당량 카드** — 메뉴바 드롭다운 패널에 추가
- **Enterprise 시트 잔여 표시** — 플로팅 필(확장 상태) 및 메뉴바 라벨에 잔여 금액 표시
- **Enterprise 설정 섹션** — 조직명, 시트 티어, 모든 지출 한도 정보를 설정 화면에 표시

### 개선 사항

- **모델 가격 업데이트** — 최신 모델에 맞는 MTok당 정확한 요금 반영:
  - Opus 4.5/4.6 ($5/$25) 및 Opus 4.0/4.1 ($15/$75)을 별도 항목으로 분리
  - Haiku 4.5 ($1/$5) 추가
- **`formatPlanName` 통합** — 3곳에 중복되던 헬퍼 함수를 `PlanTier.displayName(for:)` 단일 static 메서드로 교체
- **CI/CD 강화** — 릴리스 워크플로우에 SHA-256 검증 스텝 추가, `TAP_TOKEN` 지원으로 Homebrew tap 동기화 개선

### 내부 변경

- `SpendingLimit`, `EnterpriseSeatTier`, `EnterpriseQuota` 데이터 모델 추가
- `AnthropicAPIService`에 Enterprise 할당량 파싱 로직 추가
- `UsageDataService`, `UsageDataServiceProtocol`, `MenuBarViewModel`에 Enterprise 프로퍼티 확장
- `EnterpriseQuotaCardView` 신규 컴포넌트 (3가지 프리뷰 상태 포함)

### 변경된 파일

- 수정: 14개 파일
- 추가: 1개 파일 (`EnterpriseQuotaCardView.swift`)
