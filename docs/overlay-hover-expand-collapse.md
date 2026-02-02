# Overlay Hover Expand/Collapse 리디자인

Overlay를 평소에는 아주 작은 퍼센트 pill로 표시하고, 마우스 호버 시 부드러운 애니메이션과 함께 펼쳐서 전체 정보를 보여준다.

## 핵심 동작

- **Compact (기본)**: 작은 glass capsule에 `72%` + 컬러 indicator만 표시 (~50x26)
- **Expanded (호버)**: 현재처럼 gauge ring + cost + sessions 표시 (~130x180)
- **전환**: spring 애니메이션으로 부드럽게 morphing
- click-through 모드에서는 항상 compact (hover 감지 불가)

## 수정 파일

### `Sources/Amarillo/Views/Overlay/OverlayView.swift` (전면 재작성)

`@State private var isExpanded = false`로 상태 관리.

**Compact 상태**:
```
┌──────────┐
│ ● 72%    │  ← 컬러 dot + 퍼센트, glass capsule
└──────────┘
```
- tintColor dot (4px) + 퍼센트 텍스트 (size 13, bold, monospaced rounded)
- `.glassEffect(.regular.tint(tintColor.opacity(0.3)), in: .capsule)`
- padding: horizontal 10, vertical 6

**Expanded 상태**:
```
┌─────────────────┐
│    ╭──────╮     │
│    │  72% │     │ ← gauge ring (64x64)
│    │ left │     │
│    ╰──────╯     │
│     $3.50       │ ← cost
│    ● 2 active   │ ← sessions (있을 때만)
│                 │
│  5h 56% · 7d 72%│ ← rate limit windows (API 데이터 있을 때)
└─────────────────┘
```
- gauge ring: 64x64 (현재 72에서 약간 축소)
- 모든 보조 텍스트는 opacity transition으로 fade in
- `.glassEffect(.regular.tint(tintColor.opacity(0.3)), in: .rect(cornerRadius: 24))`
- padding: 14

**애니메이션**:
- `.onHover { hovering in withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded = hovering } }`
- gauge ring: `.scaleEffect` + `.opacity` transition
- 보조 텍스트 (cost, sessions, windows): `.opacity` + `.offset` transition (아래에서 위로 올라오면서 나타남)
- compact 퍼센트 텍스트: expanded 시 `.opacity(0)`으로 fade out

### `Sources/Amarillo/Views/Overlay/OverlayWindow.swift`

- `contentRect`를 compact 기본 사이즈가 아닌 expanded 최대 사이즈로 설정 (~180x220)
- 배경이 투명이므로 실제 보이는 것은 glass capsule만

### `Sources/Amarillo/Views/Overlay/OverlayWindowController.swift`

- `hostingView.frame`을 expanded 최대 크기에 맞게 변경 (~180x220)
- 위치 계산 시 `overlayPosition`에 따라 anchor 방향 고려:
  - topRight → 우측 상단 고정, 왼쪽+아래로 확장
  - topLeft → 좌측 상단 고정, 오른쪽+아래로 확장
  - bottomRight → 우측 하단 고정, 왼쪽+위로 확장
  - bottomLeft → 좌측 하단 고정, 오른쪽+위로 확장

OverlayView에서 `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment:)`를 사용하여 적절한 코너에 정렬.

`settings.overlayPosition`을 OverlayView에 전달하여 alignment 계산에 사용.

## Verification

1. `swift build` 성공
2. 앱 실행 후 overlay 확인:
   - 기본: 작은 pill에 퍼센트만 보임
   - 마우스 hover: spring 애니메이션으로 부드럽게 펼쳐짐
   - 마우스 벗어남: 부드럽게 접힘
3. click-through 모드에서는 항상 compact
4. 4개 position 모두에서 올바른 방향으로 확장되는지 확인
