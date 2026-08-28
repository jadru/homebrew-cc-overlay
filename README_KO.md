# CC-Overlay

> [English](README.md) · [릴리스 노트](RELEASE_NOTES_KO.md) · [기여](CONTRIBUTING.md) · [보안](SECURITY.md)

**Codex와 Claude Code 작업을 위한 로컬 우선 macOS 작업 용량 오버레이입니다.**

CC-Overlay는 집중적인 코딩 작업에 영향을 주는 Mac 상태를 작은 화면 하나에 표시합니다. CPU, 메모리 압력과 스왑, 네트워크, 남은 저장 공간, 전원, 열 상태와 Codex 또는 Claude Code의 한도 여유를 함께 확인할 수 있습니다. 이 프로젝트는 Anthropic이나 OpenAI와 제휴하거나 보증 관계에 있지 않은 독립 오픈소스 유틸리티입니다.

## 표시하는 정보

- CPU, RAM, 네트워크, SSD 여유 공간, 현재 가장 제약적인 AI 프로바이더의 잔여 한도를 담은 축소 바를 표시합니다.
- 축소 바의 각 지표를 클릭하면 간단한 상세 팝오버를 표시하며, 오른쪽 대시보드 버튼을 누르면 최근 60분 CPU·메모리 추세, 7일 AI 잔여 한도 그래프, 접근 가능한 상위 프로세스, 저장 공간, 배터리와 열 상태를 확인할 수 있습니다.
- 로컬에서 설정된 Codex와 Claude Code의 사용량 윈도우, 리셋 시각, 현재 페이스를 표시합니다.

시스템 지표는 기본적으로 2초마다, 저전력 모드에서는 5초마다 갱신합니다. 최근 60분 데이터만 메모리에 보관하며, 시스템 지표를 디스크에 저장하거나 외부로 전송하지 않습니다.

## 표시 방식과 알림

새 설치의 기본값은 모든 앱에서 보이는 축소 오버레이입니다. 설정에서 **개발 도구에서만 표시**로 바꿀 수 있습니다. 각 지표를 클릭하면 상세 팝오버를 열 수 있고, 오른쪽 대시보드 버튼을 누르면 전체 정보를 확인할 수 있습니다. 기존 단축키 `Cmd+Shift+A`는 오버레이를 토글합니다. 화면 경계 보정, 클릭 통과, 전체 화면 지원, 동작 줄이기 지원은 유지됩니다.

컨텍스트 메뉴에서 **Hide Overlay**를 선택하면 복구를 위해 CC-Overlay가 Dock에 나타나며, **Overlay → Show Overlay** 메뉴를 사용할 수 있습니다. 오버레이를 다시 표시하면 앱은 일반적인 액세서리 모드로 돌아갑니다.

macOS 알림은 설정한 AI 사용량 임계값, 상승 또는 심각한 메모리 압력, 심각한 열 상태에만 보냅니다. 같은 상태에서는 반복 알림을 보내지 않으며, Mac이 정상 상태로 돌아온 뒤에 다음 악화에서 다시 알립니다.

## 설치

```bash
brew tap jadru/cc-overlay
brew install cc-overlay
cc-overlay
```

macOS 시작 시 실행하려면 설정에서 **Launch at login**을 켭니다. CC-Overlay는 Homebrew 백그라운드 서비스를 설치하지 않습니다.

제거하려면 Launch at login을 끄고 다음을 실행합니다.

```bash
brew uninstall cc-overlay
```

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

## 데이터와 개인정보

| 데이터 | 용도 | 보관 방식 |
|---|---|---|
| CPU, 메모리, 네트워크, 저장 공간, 전원, 열 상태 | 로컬 시스템 용량 표시 | 최근 60분만 메모리에 보관 |
| Codex OAuth, app-server 메타데이터, 최근 롤아웃 토큰 카운터 | Codex 잔여 한도, 리셋 정보, 토큰 대체 표시 | 인증 정보는 Codex/macOS 저장소에 유지하며 토큰 카운터는 메모리에서 처리 |
| Claude OAuth 또는 로컬 JSONL | Claude Code 잔여 한도 | 로컬에서 처리하며 OAuth 접근은 명시적으로 켠 경우에만 사용 |
| 프로바이더 사용량 이력과 환경설정 | 기존 사용량 기능과 앱 설정 | 로컬 Mac |

CC-Overlay는 개발자가 운영하는 백엔드를 두지 않습니다. 요청한 사용량 메타데이터를 위해 프로바이더 서비스와 통신하고, 자동 업데이트를 켠 경우 GitHub Releases에만 통신합니다. 프로바이더를 활성화하기 전에 소스를 검토하고 신뢰할 수 있는 릴리스만 사용하세요.

## 설정

| 설정 | 기본값 | 설명 |
|---|---:|---|
| 오버레이 표시 방식 | 모든 앱 | 모든 앱 또는 개발 도구에서만 표시하도록 선택합니다. |
| 플로팅 오버레이 표시 | 켬 | 플로팅 시스템 모니터를 보이거나 숨깁니다. |
| 클릭 통과 | 끔 | 오버레이 아래 앱으로 포인터 입력을 전달합니다. |
| 글로벌 단축키 | 켬 | `Cmd+Shift+A`로 오버레이를 토글합니다. |
| 사용량 임계값 알림 | 켬 | 설정한 프로바이더 사용량 임계값에서 알립니다. |
| Claude OAuth rate limit | 끔 | 명시적으로 켠 경우에만 Claude Keychain 인증 정보를 읽습니다. |
| Launch at login | 끔 | macOS 시작 시 CC-Overlay를 실행합니다. |

## 라이선스와 피드백

[MIT](LICENSE)로 배포합니다. 앱의 **Settings → Advanced → Share product feedback**을 사용하거나 [피드백 이슈](https://github.com/jadru/homebrew-cc-overlay/issues/new?template=user_feedback.yml)를 열어 주세요. 안전한 진단 정보에는 인증 정보, 프로젝트 이름, 사용량 이력, 로컬 경로가 포함되지 않습니다.
