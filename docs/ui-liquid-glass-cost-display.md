# UI 리디자인: Liquid Glass + 달러 비용 표시

## 요약

1. API 토큰 기반 **달러($) 비용 계산기** 추가 (모델별 정확한 가격 적용)
2. **오버레이** — 원형 프로그레스 링 + glass squircle 위젯으로 재설계
3. **메뉴바 팝오버** — `GlassEffectContainer` + glass 카드 기반 레이아웃
4. **메뉴바 라벨** — 비용 표시 추가

---

## 수정 파일 (10개)

| 파일 | 변경 |
|------|------|
| `Models/CostCalculator.swift` | **신규** — 모델별 가격, CostBreakdown, 계산 로직 |
| `Models/UsageData.swift` | `AggregatedUsage`에 `fiveHourCost`, `dailyCost` 필드 추가 |
| `Services/UsageCalculator.swift` | `aggregate()`에서 비용 계산 호출 |
| `Utilities/NumberFormatting.swift` | `formatDollarCost()`, `formatDollarCompact()` 추가 |
| `Views/Overlay/OverlayView.swift` | **전면 재작성** — 원형 링 + glass squircle |
| `Views/Overlay/OverlayWindow.swift` | 윈도우 크기 160x90 → 140x140 |
| `Views/Overlay/OverlayWindowController.swift` | hostingView 크기 동기화 |
| `Views/MenuBar/MenuBarView.swift` | **전면 재작성** — glass 카드 기반 |
| `Views/MenuBar/MenuBarLabel.swift` | 달러 비용 추가 표시 |
| `Tests/CostCalculatorTests.swift` | **신규** — 가격 조회, 비용 계산 테스트 |

---

## 1. CostCalculator (신규 파일)

`Sources/Amarillo/Models/CostCalculator.swift`

### 모델별 가격 테이블

| 모델 prefix | Input/MTok | Output/MTok | Cache Write/MTok | Cache Read/MTok |
|------------|-----------|------------|-----------------|----------------|
| `claude-opus-4` | $15 | $75 | $18.75 | $1.50 |
| `claude-sonnet-4` | $3 | $15 | $3.75 | $0.30 |
| `claude-3-5-haiku` | $0.80 | $4 | $1.00 | $0.08 |
| fallback (unknown) | $3 | $15 | $3.75 | $0.30 |

### 구조체

- `ModelPricing` — 모델별 MTok 단가 4종
- `CostBreakdown` — input/output/cacheWrite/cacheRead 비용 + `totalCost` 계산 + `+` 연산자
- `CostCalculator.cost(for: ParsedUsageEntry)` — 개별 엔트리 비용
- `CostCalculator.cost(for: [ParsedUsageEntry])` — 엔트리 배열 비용 합산
- `CostCalculator.cost(for: SessionUsage)` — 세션별 비용

핵심: `TokenUsage`는 모델 정보가 없으므로 직접 비용 계산 불가. 반드시 `ParsedUsageEntry`(모델 포함) 단위로 계산 후 합산.

---

## 2. UsageData.swift 수정

`AggregatedUsage`에 2개 필드 추가:

```swift
struct AggregatedUsage: Sendable {
    // ... 기존 필드 ...
    let fiveHourCost: CostBreakdown   // 5시간 윈도우 비용
    let dailyCost: CostBreakdown      // 오늘 비용
}
```

`.empty` static도 `.zero` 값으로 업데이트.

---

## 3. UsageCalculator.swift 수정

`aggregate()` 메서드에서 CostCalculator 호출 추가:

```swift
let windowCost = CostCalculator.cost(for: windowEntries)
let dailyCost = CostCalculator.cost(for: dailyEntries)
// AggregatedUsage 생성자에 전달
```

---

## 4. NumberFormatting.swift 수정

2개 함수 추가:

```swift
static func formatDollarCost(_ amount: Double) -> String
// 0.42 → "$0.42", 3.7 → "$3.70", 0.001 → "<$0.01"

static func formatDollarCompact(_ amount: Double) -> String
// 0.42 → "42c", 3.70 → "$3.70", 0.001 → "<1c"
```

---

## 5. 오버레이 리디자인

`OverlayView.swift` — 전면 재작성

### 디자인 컨셉

현재 (capsule + text only) → **원형 프로그레스 링** 중심의 glass squircle 위젯

```
┌──────────────────┐
│                  │
│    ╭──────╮      │
│    │ ring │      │  ← 72x72 프로그레스 링
│    │ 44%  │      │     남은 % 중앙 표시
│    │ left │      │
│    ╰──────╯      │
│     $3.70        │  ← 5시간 비용
│                  │
└──────────────────┘
 .glassEffect(.regular.tint(color), in: .rect(cornerRadius: 28))
```

### 뷰 구조

```swift
VStack(spacing: 6) {
    // 프로그레스 링
    ZStack {
        Circle().stroke(secondary 0.15, lineWidth: 5)        // 배경 트랙
        Circle().trim(0...usedPct/100).stroke(tint, 5pt)     // 진행 아크 (애니메이션)
        VStack {
            Text("44%")  // 20pt bold rounded
            Text("left") // 9pt medium secondary
        }
    }
    .frame(72x72)

    // 비용 라벨
    Text("$3.70")  // 11pt semibold rounded secondary
}
.padding(16)
.glassEffect(.regular.tint(tintColor.opacity(0.3)), in: .rect(cornerRadius: 28))
```

### 색상 로직 (tintColor)

- remainPct <= 10 → `.red`
- remainPct <= 30 → `.orange`
- remainPct <= 60 → `.yellow`
- else → `.green`

Tint는 `opacity(0.3)`으로 glass 투명성 유지.

### 윈도우 크기 변경

- `OverlayWindow.swift` contentRect: 160x90 → **140x140**
- `OverlayWindowController.swift` hostingView.frame: 160x90 → **140x140**

---

## 6. 메뉴바 팝오버 리디자인

`MenuBarView.swift` — 전면 재작성

### 디자인 컨셉

`GlassEffectContainer`로 전체 감싸고, 각 섹션을 glass 카드로 표현.

### 레이아웃 (width: 300)

```
┌─ GlassEffectContainer ──────────────────┐
│                                         │
│  Claude Code           [⟳]  ← glass circle interactive refresh
│  Max ($100/mo)                          │
│                                         │
│  ┌─ glass card (primary gauge) ────────┐│
│  │  Session Limit                      ││
│  │       ╭──────╮                      ││
│  │       │ ring │  88x88               ││
│  │       │ 44%  │                      ││
│  │       │ rem  │                      ││
│  │       ╰──────╯                      ││
│  │  [5h 56%] [7d 72%] [Sonnet 12%]    ││  ← glass capsule pills
│  │  ⏰ Resets in 3h            ● Live  ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─ glass card (cost) ────────────────┐ │
│  │  Estimated Cost           $        │ │
│  │     $3.70      │     $12.45        │ │
│  │    5h window    │     today         │ │
│  │  ● In $0.12  ● Out $2.80  ...     │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ┌─ glass card (tokens) ──────────────┐ │
│  │  5-Hour Tokens                     │ │
│  │  (기존 TokenBreakdownView)          │ │
│  └────────────────────────────────────┘ │
│                                         │
│  [Overlay toggle]         [⚙ Settings]  │  ← Settings 버튼: glass capsule interactive
│                                         │
│  Updated 30s ago                        │
│                                         │
└─────────────────────────────────────────┘
```

### Glass 사용 포인트

- 전체: `GlassEffectContainer { ... }` — 자식 glass 요소 시각적 통일
- 리프레시 버튼: `.glassEffect(.regular.interactive(), in: .circle)` — 누르면 bounce
- Primary gauge 카드: `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
- Window pills (5h/7d/Sonnet): `.glassEffect(.regular, in: .capsule)` — glass 캡슐
- Cost 카드: `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
- Token breakdown 카드: `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
- Settings 버튼: `.glassEffect(.regular.interactive(), in: .capsule)`

### 헬퍼 함수

- `windowPill(label, bucket)` — glass capsule pill 뷰
- `costChip(label, amount, color)` — 색상 dot + 비용 텍스트
- `windowLabel(String)` — "five_hour" → "Session Limit"
- `formatPlanName(String)` — "max_5" → "Max ($100/mo)"

---

## 7. 메뉴바 라벨 수정

`MenuBarLabel.swift` — 비용 추가 표시 (선택적)

```swift
HStack(spacing: 4) {
    Image(systemName: "chart.bar.fill")
    if hasData {
        Text("44%")           // 기존: 남은 %
        if cost > 0 {
            Text("$3.70")     // 신규: 5시간 비용 (caption2, secondary)
        }
    }
}
```

---

## 구현 순서

1. `CostCalculator.swift` 생성 + `CostCalculatorTests.swift` 생성
2. `UsageData.swift` — `AggregatedUsage`에 cost 필드 추가
3. `UsageCalculator.swift` — `aggregate()`에 cost 계산 추가
4. `NumberFormatting.swift` — 달러 포맷 함수 추가
5. `OverlayView.swift` — 전면 재작성
6. `OverlayWindow.swift` — 크기 변경 (140x140)
7. `OverlayWindowController.swift` — 크기 동기화
8. `MenuBarView.swift` — 전면 재작성
9. `MenuBarLabel.swift` — 비용 표시 추가

---

## 검증

1. `swift build` 성공
2. `swift test` — CostCalculator 테스트 통과
3. 앱 실행 → 오버레이에 원형 링 + 비용 표시 확인
4. 메뉴바 팝오버에 glass 카드 레이아웃 확인
5. 비용이 합리적인 범위인지 확인 (5시간 사용량 기준 $0~$50 정도)
6. 색상 tint가 사용량에 따라 변하는지 확인
