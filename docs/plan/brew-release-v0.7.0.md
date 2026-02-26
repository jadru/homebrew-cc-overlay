# Brew Release 준비 (v0.7.0)

## 이번 준비에서 완료한 것
- 앱 버전 상수/번들 버전: `0.7.0`로 상향
- 릴리즈 노트 초안 추가 (`RELEASE_NOTES.md`, `RELEASE_NOTES_KO.md`)
- 미진행 작업 분리 문서화 (`docs/plan/todo.md`)

## 배포 전 체크
1. `swift build` / `swift test` 확인
2. 릴리즈 노트 내용 최종 검수
3. 태그 생성: `git tag v0.7.0 && git push origin v0.7.0`

## 태그 푸시 후 자동화
- `.github/workflows/release.yml`가 자동으로 수행:
  - universal binary 빌드 및 tarball 업로드
  - SHA-256 계산
  - `Formula/cc-overlay.rb`의 `url`/`sha256` 자동 갱신
  - tap 저장소(`jadru/homebrew-cc-overlay`) 동기화

## 수동 검증
1. GitHub Release에 asset/sha256 업로드 확인
2. Formula가 `v0.7.0` + 새 sha256으로 반영됐는지 확인
3. 로컬 테스트
   - `brew update`
   - `brew upgrade cc-overlay` 또는 신규 설치 `brew install cc-overlay`
   - `brew services restart cc-overlay`
