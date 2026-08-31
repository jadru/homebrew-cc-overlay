# CC-Overlay

> [English](README.md) · [릴리스 노트](RELEASE_NOTES_KO.md) · [제품 정의](PRODUCT.md) · [기여](CONTRIBUTING.md) · [보안](SECURITY.md)

**코딩을 시작하기 전에 Mac과 AI 사용량이 준비되었는지 판단하는 로컬 우선 macOS 용량 코파일럿입니다.**

CC-Overlay는 Codex와 Claude Code를 사용하는 개발자를 위한 로컬 우선 macOS 용량 코파일럿입니다. 집중적인 AI 코딩 작업을 중단시킬 수 있는 Mac 상태, 프로바이더 여유 한도, 리셋 시각, 다음 안전한 행동을 작은 화면 하나에 모아 보여 줍니다.

이 프로젝트는 Anthropic이나 OpenAI와 제휴하거나 보증 관계에 있지 않은 독립 오픈소스 유틸리티입니다.

## 오버레이 화면

작업 공간에 맞는 모양을 선택할 수 있습니다. 세 레이아웃 모두 CPU, RAM, 네트워크, SSD, AI 사용량, 대시보드 제어를 동일하게 제공합니다.

| 가로형 | 세로형 | 2열형 |
|:---:|:---:|:---:|
| <img src="docs/images/overlay-horizontal.png" width="329" alt="CPU, RAM, 네트워크, SSD, AI 사용량, 대시보드 버튼을 포함한 CC-Overlay 가로형"> | <img src="docs/images/overlay-vertical.png" width="127" alt="지표를 한 행씩 표시하는 CC-Overlay 세로형"> | <img src="docs/images/overlay-two-column.png" width="125" alt="2열 그리드 형태의 CC-Overlay"> |
| 가장 작은 한 줄 점유 공간 | 지표를 한 행씩 읽는 구성 | 좁은 공간에서 빠르게 훑는 균형형 구성 |

스크린샷은 `v1.1.1` 로컬 빌드에서 캡처했습니다. 수치는 캡처 당시 Mac의 실제 샘플이며 특정 용량 수준을 보장하지 않습니다.

## 한눈에 작업 용량을 판단합니다

작업을 시작하기 전에 CC-Overlay로 다음 세 가지를 확인합니다.

1. **Mac이 준비되었나요?** CPU, 메모리 압력, 열 상태, 남은 저장 공간과 보조 신호인 네트워크를 확인합니다.
2. **어느 프로바이더에 여유가 있나요?** 로컬에서 사용할 수 있는 Codex와 Claude Code의 사용량 윈도우, 리셋 시각, 7일 헤드룸 이력을 확인합니다.
3. **지금 무엇을 해야 하나요?** 대시보드의 **Next action** 카드가 즉시 실행, 주의 실행, 새로고침, 프로바이더 전환, 한도 대기, Mac 회복 대기 중 하나와 근거를 설명합니다.

결정 순서는 고정되어 있습니다. Mac의 치명 상태를 먼저 처리하고, 프로바이더 설정이나 새로고침 필요 상태를 그다음 처리합니다. 이후 한도, 리셋, 프로바이더 전환을 판단합니다. 주의 상태에는 원인을 반드시 표시하며, Mac 치명 상태에는 근거 없는 회복 시각을 추정하지 않습니다.

| Next action | 표시 조건 | 안내 내용 |
|---|---|---|
| **Wait for Mac** | 메모리 압력 또는 열 상태가 critical입니다. | 집중 작업을 시작하지 말고, Mac이 회복 상태를 보고한 뒤 다시 확인합니다. |
| **Refresh / Set up** | 프로바이더 데이터가 오래되었거나, 없거나, 설정이 필요합니다. | 프로바이더 추천을 믿기 전에 다시 연결하거나 새로고침합니다. |
| **Wait / Switch / Use reset** | 사용할 수 있는 프로바이더의 한도가 부족합니다. | 가장 이른 리셋을 기다리거나 다른 프로바이더 또는 적용 가능한 Codex 리셋을 사용합니다. |
| **Run with caution** | 메모리 압력 warning, 열 상태 serious, CPU 또는 RAM 90% 이상, 남은 저장 공간 10GiB 미만입니다. | 실행은 가능하지만 카드에 Mac 위험 원인을 구체적으로 표시합니다. |
| **Run now** | Mac과 프로바이더 모두에 차단 조건이 없습니다. | 권장 프로바이더와 신뢰도를 확인한 뒤 바로 시작합니다. |

이번 릴리스에서 네트워크와 배터리는 유용한 맥락 정보이지만, 단독으로 실행을 차단하지는 않습니다.

## 화면에서 확인하는 정보

### 플로팅 오버레이

- **시스템 신호:** CPU, RAM, 네트워크 전송 속도, 남은 SSD 공간, 로컬에서 사용할 수 있는 AI 프로바이더 중 가장 제한적인 항목을 표시합니다.
- **세 가지 영구 레이아웃:** 오버레이를 오른쪽 클릭해 **Layout** 메뉴에서 **Horizontal**, **Vertical**, **Two columns**를 선택하거나 **Settings → Overlay**에서 선택합니다. 선택한 레이아웃은 앱을 다시 실행해도 유지됩니다.
- **집중 상세 정보:** CPU, RAM, 네트워크, SSD, AI 사용량을 클릭하면 간결한 상세 팝오버를 엽니다. AI 팝오버에는 대시보드와 같은 높이 48pt의 7일 다중 프로바이더 헤드룸 그래프가 표시됩니다. 이력이 아직 없으면 같은 영역에 로컬 이력을 만드는 방법을 표시합니다.
- **대시보드:** 오른쪽의 격자 버튼을 누르면 Next action 카드, 최근 60분 CPU·RAM 추세, 저장 공간, 배터리가 있는 경우 전원 상태, 열 상태, 접근 가능한 상위 프로세스를 확인할 수 있습니다.

오버레이는 드래그해도 현재 디스플레이 안에 머무르며, 전체 화면 앱 위에서도 동작합니다. **Click-through**를 켜면 아래 앱으로 포인터 입력을 전달할 수 있습니다.

### 프로바이더와 프로젝트 인사이트

대시보드의 사용량 상세 화면에서 현재 프로바이더 윈도우와 로컬 7일 헤드룸 이력을 비교할 수 있습니다. Project activity 섹션은 최근 24시간의 활동을 프로젝트별로 묶고, 먼저 상위 3개를 보여 준 뒤 전체 로컬 목록을 펼칠 수 있습니다.

| 프로바이더 | 로컬 인사이트 | 비용 표시 원칙 |
|---|---|---|
| **Codex** | `session_meta.cwd`와 로컬 rollout의 누적 토큰 카운터에서 양의 변화분만 결합합니다. 중복되거나 감소한 카운터는 합계를 부풀리지 않습니다. | **Codex local tokens**와 한도 기여도만 표시합니다. 실제 Codex 청구액처럼 달러 비용을 표시하지 않습니다. |
| **Claude Code** | 로컬 JSONL 세션을 프로젝트, 모델, 토큰 기준으로 집계합니다. OAuth 사용량 한도 접근은 명시적으로 켜야 합니다. | 달러 정보는 반드시 **Claude local API-equivalent estimate**로 명시할 때만 표시합니다. |

프로젝트 이름에는 경로의 마지막 디렉터리명만 사용합니다. 원본 경로, 대화 내용, 토큰 원장은 환경설정, 안전 진단, CSV 내보내기에 새로 저장하지 않습니다. 손상된 로컬 레코드나 안전 읽기 한도 초과는 해당 프로젝트 카드에만 영향을 주며, 사용량 한도 모니터링은 계속 동작합니다.

## 설치와 업데이트

```bash
brew tap jadru/cc-overlay
brew install cc-overlay
cc-overlay
```

기존 설치본은 다음 명령으로 업데이트합니다.

```bash
brew update
brew upgrade cc-overlay
```

macOS 시작 시 실행하려면 Settings에서 **Launch at login**을 켭니다. CC-Overlay는 Homebrew 백그라운드 서비스를 설치하지 않습니다.

제거하려면 Launch at login을 끄고 다음을 실행합니다.

```bash
brew uninstall cc-overlay
```

## 일상적인 사용 방법

- `Cmd+Shift+A`를 눌러 오버레이를 보이거나 숨깁니다.
- 오버레이를 오른쪽 클릭해 대시보드를 열고, 레이아웃을 바꾸고, 오버레이를 숨기거나 앱을 종료할 수 있습니다.
- **Settings → Overlay**에서 저장된 레이아웃을 확인하고, 모든 앱 또는 인식된 개발 도구에서만 표시하도록 선택하며, Click-through를 켭니다.
- 대시보드의 톱니바퀴 버튼을 클릭하면 Settings를 바로 엽니다.
- 컨텍스트 메뉴에서 오버레이를 숨기면 CC-Overlay가 잠시 Dock에 표시됩니다. **Overlay → Show Overlay**로 다시 표시할 수 있습니다.

## 설정

| 설정 | 기본값 | 설명 |
|---|---:|---|
| 오버레이 레이아웃 | 가로형 | 가로형, 세로형, 2열형 중 하나를 선택하며 선택값은 로컬에 유지됩니다. |
| 오버레이 표시 방식 | 모든 앱 | 모든 앱 또는 인식된 개발 도구에서만 표시하도록 선택합니다. |
| 플로팅 오버레이 표시 | 켬 | 플로팅 시스템 모니터를 보이거나 숨깁니다. |
| 클릭 통과 | 끔 | 오버레이 아래 앱으로 포인터 입력을 전달합니다. |
| 글로벌 단축키 | 켬 | `Cmd+Shift+A`로 오버레이를 토글합니다. |
| 사용량 임계값 알림 | 켬 | 설정한 프로바이더 사용량 임계값에서 알립니다. |
| Claude OAuth rate limit | 끔 | 명시적으로 켠 경우에만 Claude Keychain 인증 정보를 읽습니다. |
| Launch at login | 끔 | macOS 시작 시 CC-Overlay를 실행합니다. |

## 데이터와 개인정보

CC-Overlay는 개발자가 운영하는 백엔드를 두지 않습니다. 요청한 사용량 메타데이터를 위해 프로바이더 서비스와 통신하고, 자동 업데이트를 켠 경우 GitHub Releases에만 통신합니다.

| 데이터 | 용도 | 보관 방식과 경계 |
|---|---|---|
| CPU, 메모리, 네트워크, 저장 공간, 전원, 열 상태 | 로컬 시스템 용량 표시 | 최근 60분만 메모리에 보관하며 외부로 전송하지 않습니다. |
| 프로바이더 헤드룸, 리셋 메타데이터, 환경설정 | 용량 추천과 오버레이 동작 | 사용자의 Mac에 로컬로 보관합니다. |
| Codex rollout 카운터와 Claude JSONL 레코드 | 로컬 프로젝트 활동과 토큰 인사이트 | 로컬에서 처리하며 원본 경로, 대화 내용, 토큰 원장을 새로 저장하거나 내보내지 않습니다. |
| Claude OAuth 인증 정보 | 선택적 Claude 사용량 한도 조회 | 명시적으로 켠 경우에만 요청하며 기존 macOS·Claude 저장소에 유지합니다. |

프로바이더를 활성화하기 전에 소스를 검토하고 신뢰할 수 있는 릴리스만 사용하세요. 안전한 진단 정보에는 인증 정보, 프로젝트 이름, 사용량 이력, 로컬 경로가 포함되지 않습니다.

## 빌드와 검증

Swift 6.0+와 macOS 15+ SDK가 필요합니다.

```bash
git clone https://github.com/jadru/homebrew-cc-overlay.git
cd homebrew-cc-overlay
./script/build_and_run.sh
swift test
```

notarization 없이 universal packaging 검사를 실행하려면 다음을 사용합니다.

```bash
VERSION=0.0.0 BUILD_NUMBER=0 SIGN_IDENTITY=- NOTARIZE=0 ARCHS="arm64 x86_64" ./script/package_release.sh
```

태그 릴리스는 서명과 notarization을 거친 universal app bundle입니다. Homebrew 설치본은 다음처럼 확인할 수 있습니다.

```bash
APP="$(brew --prefix cc-overlay)/CC-Overlay.app"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
```

## 라이선스와 피드백

[MIT](LICENSE)로 배포합니다. 앱의 **Settings → Advanced → Share product feedback**을 사용하거나 [피드백 이슈](https://github.com/jadru/homebrew-cc-overlay/issues/new?template=user_feedback.yml)를 열어 주세요.
