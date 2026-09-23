# GitHub Actions CI

## 목표

- `.github/workflows/ci.yml` 하나가 PR과 `main` 푸시마다 두 잡을 병렬로 돌린다.
  - `lint`: `swiftformat --lint .`, `swiftlint lint --quiet`, `Scripts/openapi-generate.sh --check`
  - `build-test`: `tuist install` → `tuist generate --no-open` → `xcbuild.sh test` → `xcbuild.sh build -configuration Release`
- 테스트가 실패하면 `.xcresult` 번들이 잡 아티팩트로 올라간다. 성공하면 올리지 않는다.
- Tuist 계정, 시크릿, 저장소 변수가 **하나도 없는 상태에서** 템플릿을 복제해도 워크플로가 그대로 돈다.
- 워크플로 파일에 앱 이름(`TuistApp`)과 스킴·워크스페이스 이름이 하드코딩되지 않는다. 이름은 `xcbuild.sh`의 `SCHEME`·`PROJECT_FLAGS` 한 곳에만 있다.
- 러너 라벨은 기본값 `xcode-27`이고, 저장소 변수 `MACOS_RUNNER`로 코드 수정 없이 바꿀 수 있다.
- README에 CI 절이 생기고, "새 앱으로 복제할 때 바꿀 곳"과 Xcode 메이저 버전을 올릴 때 함께 바꿀 곳이 적힌다.
- 실제 PR에서 두 잡이 모두 초록으로 끝나는 것을 한 번 확인한다.

## 범위 밖

- Tuist 서버(원격 바이너리 캐시, 선택적 테스트, `tuist auth login`, `TUIST_TOKEN`). 이번엔 계정 없는 경로만 만든다.
- Xcode Cloud(`ci_scripts/`).
- 서명, 아카이브, TestFlight/App Store 배포, Crashlytics dSYM 실제 업로드.
- JUnit 변환, 테스트별 PR 체크 리포트.
- DerivedData 캐시. Tuist 생성 프로젝트에서 효과가 불안정하고 캐시 크기가 크다. 필요하면 후속 작업.
- 브랜치 보호 규칙과 required status check 설정(저장소 설정이라 코드로 못 넣는다. README에 권장만 적는다).
- `paths-ignore`로 문서 전용 PR을 건너뛰는 것. required check로 걸면 건너뛴 워크플로가 머지를 막는다.
- 스냅샷 테스트 기준 이미지를 CI 기기에 맞추는 작업(현재 CI 기기에서 깨지면 위험 요소 참고).

## 전제

### 환경
- iOS 17.0(`Tuist/ProjectDescriptionHelpers/AppConstants.swift`), Swift 6, Xcode 27.
- `Tuist.swift:11` `compatibleXcodeVersions: .upToNextMajor("27.0")`. Xcode 27.x가 아니면 `tuist generate`가 멈춘다.
- 도구 버전은 `mise.toml` 하나로 고정된다: `tuist 4.208.0`, `swiftformat 0.63.0`, `swiftlint 0.65.1`, `"spm:apple/swift-openapi-generator" = "1.13.1"`. 마지막 항목은 mise가 소스에서 빌드하므로 캐시가 없으면 첫 설치가 몇 분 걸린다.
- 외부 SPM 의존성: swift-openapi-runtime·urlsession, http-types, firebase-ios-sdk 12.19.2. `Tuist/Package.resolved`는 커밋되어 있다. `tuist install`은 `Tuist/.build/`(gitignore)에 받는다.
- `.xcworkspace`, `.xcodeproj`는 gitignore 대상인 생성물이다. CI는 매번 `tuist install` → `tuist generate --no-open`을 먼저 해야 한다.

### 러너
- GitHub 호스티드 러너 중 Xcode 27이 있는 것은 `xcode-27`(또는 `xcode-27-xlarge`) 라벨뿐이다. arm64, **preview** 상태. Xcode 27.0(27A266a), iOS 27.0 시뮬레이터 포함.
  - 출처: https://raw.githubusercontent.com/actions/runner-images/main/images/macos/xcode-27-arm64-Readme.md, https://github.com/actions/runner-images/issues/14404
- `macos-26`/`macos-latest`는 Xcode 26.6까지라 쓸 수 없다.
- `runs-on`은 `vars` 컨텍스트를 받는다: `runs-on: ${{ vars.MACOS_RUNNER || 'xcode-27' }}`.
- `jq`는 GitHub macOS 이미지에 기본으로 있다. `xcbeautify` 포함 여부는 **구현 중 확인**(이미지 README의 도구 목록). 없어도 `xcbuild.sh`가 날 `xcodebuild` 출력으로 폴백하므로 잡은 깨지지 않는다.
  - 확인 결과(2026-09-23, 이미지 20260912.0186.1): `jq 1.8.2`, `Xcbeautify 3.2.1`. 3.2.1은 `--renderer github-actions`를 지원한다.
  - xcbeautify만 `mise.toml`이 아니라 이미지에 기댄다. 이미지 버전이 `--renderer`를 모르면 `xcbuild.sh`가 옵션을 붙이지 않는다(`--help`로 확인). 없으면 인라인 주석만 빠진다.

### 액션
- `jdx/mise-action@v4`: `mise.toml`의 도구를 설치하고 PATH에 올린다. 입력 `cache`는 기본 true. 설치된 도구가 PATH의 `swiftlint`·`swiftformat`·`tuist`로 바로 잡히는지 **구현 중 확인**. 안 잡히면 `mise exec --`로 감싼다(`Scripts/openapi-generate.sh`는 이미 `mise exec --`를 쓴다).
- `actions/checkout`, `actions/cache`, `actions/upload-artifact`의 현행 메이저는 **구현 중 확인**(Tuist 공식 문서 예제의 `checkout@v4`, `mise-action@v2`는 낡았다).

### 기존 스크립트를 CI에서 그대로 쓸 수 있는 근거
- `.claude/scripts/xcbuild.sh`의 `resolve()`는 ① `IOS_SIM_UDID` ② `.claude/sim.local` 캐시 ③ `pick_simulator`(가장 높은 iOS 런타임의 iPhone) 순으로 고른다. CI 러너에는 캐시가 없으니 ③이 돌고 러너에 캐시 파일을 쓴다. 러너는 일회성이라 무해하다. **스크립트에 CI 분기를 넣을 필요가 없다.**
- `xcbuild.sh`는 `set -euo pipefail`이고 `xcodebuild | xcbeautify` 파이프라인이라 빌드 실패가 종료 코드로 전파된다.
- 추가 인자는 `"$@"`로 `xcodebuild`에 넘어간다. `-resultBundlePath <경로>`, `-configuration Release`를 그대로 붙일 수 있다.
- `Configurations/Debug.xcconfig`(및 Release)는 `#include? "ClientKeys.xcconfig"`로 키 파일을 읽는다. `?`라서 파일이 없어도 빌드가 깨지지 않는다. **CI에서 `.example`을 복사할 필요 없다.**
- `Scripts/crashlytics-upload-symbols.sh`는 Release가 아니거나 `App/Resources/GoogleService-Info.plist`가 없으면 경고만 남기고 `exit 0`이다. plist는 저장소에 없다. Release 빌드가 CI에서 깨지지 않는다.
- `Scripts/openapi-generate.sh --check`는 생성물을 임시 디렉터리에 만들어 커밋된 `Modules/Core/Networking/Sources/Generated/`와 `diff -r`한다. 다르면 exit 1.
- 린트 기준은 훅(`.claude/hooks/swift-quality.sh`)과 같게 맞춘다.
  - `swiftformat --lint`. 제외 규칙은 `.swiftformat`의 `--exclude`(Derived, Tuist/.build, *.generated.swift).
  - `swiftlint lint --quiet`를 루트에서 `--config` 없이 실행한다(중첩 설정 적용). `.swiftlint.yml` 주석대로 **`--strict` 금지**. error 심각도만 실패시킨다(swiftlint는 `--strict` 없이 warning으로는 0이 아닌 코드로 끝나지 않는다).
- 스킴 `TuistApp-Workspace`(`Scheme+Workspace.swift`)는 빌드 액션에 앱·모듈·데모 앱만, 테스트 액션에 모든 테스트 타깃을 넣는다. 그래서 `build -configuration Release`가 테스트 타깃을 컴파일하지 않는다. CI의 Release 빌드가 이 설계를 지킨다.

### xcbeautify GitHub 렌더러
- `xcbeautify --renderer github-actions`는 컴파일 에러·테스트 실패를 PR 파일 뷰의 인라인 주석으로 바꾼다. 설치된 xcbeautify 버전이 이 옵션을 지원하는지 **구현 중 확인**.
- GitHub Actions는 `GITHUB_ACTIONS=true`를 설정한다.

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| CI 플랫폼 | GitHub Actions + mise (사용자 선택) | 로컬과 같은 `mise.toml`로 버전이 정확히 맞는다. 저장소에 들어 있어 템플릿 복제만으로 동작한다. Xcode Cloud는 설정이 App Store Connect에 있어 복제되지 않는다 |
| Tuist 서버 | 쓰지 않음 | 템플릿 사용자에게 계정 가입을 강요하지 않는다. 필요하면 후속 작업으로 시크릿 조건부 스텝을 붙인다 |
| 검사 범위 | 포맷·린트, OpenAPI `--check`, Debug 테스트, Release 빌드 (사용자 선택) | 훅이 편집 시점에만 막는 것을 병합 시점에도 강제한다. Release 빌드는 스킴 설계(테스트 타깃 제외)와 Crashlytics 스크립트의 조건 분기를 지킨다 |
| 결과 보고 | 실패 시 `.xcresult` 업로드 (사용자 선택) | 새 도구가 없다. Xcode로 열어 실패 원인과 첨부를 그대로 본다 |
| 빌드·테스트 진입점 | `xcbuild.sh`를 그대로 호출 | **저장소 조사와의 충돌**: 조사는 시뮬레이터 캐시 때문에 CI 분기가 필요할 수 있다고 봤다. 코드를 읽어 보니 캐시가 없을 때 새로 고르고 쓰기만 하므로 그대로 동작한다. 스킴·워크스페이스 이름을 한 곳(`xcbuild.sh`)에만 두는 이점이 크다 |
| `xcbuild.sh` 변경 | `GITHUB_ACTIONS=true`일 때만 xcbeautify에 `--renderer github-actions`를 붙인다 | 한 줄 분기로 PR 인라인 주석을 얻는다. 로컬 동작은 그대로다. 옵션을 지원하지 않는 버전이면 이 단계를 빼고 계획을 그대로 진행한다 |
| 잡 구성 | `lint`와 `build-test` 두 잡 병렬 | 린트 실패를 몇 분 안에 알려 준다. 빌드 잡이 20분 넘게 걸려도 린트 피드백이 기다리지 않는다 |
| 러너 | `${{ vars.MACOS_RUNNER \|\| 'xcode-27' }}`, 두 잡 공통 | Xcode 27을 주는 호스티드 러너는 이것뿐이다. preview가 GA 라벨로 바뀌거나 자체 호스팅으로 옮길 때 코드 수정 없이 바꾼다 |
| 시뮬레이터 | `xcbuild.sh`의 자동 선택(`pick_simulator`) | 러너 이미지가 바뀌어도 가장 높은 iOS의 iPhone을 고른다. 기기 이름을 워크플로에 적지 않는다 |
| 캐시 | mise-action 기본 캐시 + `actions/cache`로 `Tuist/.build` | 키는 `hashFiles('Tuist/Package.resolved', 'Tuist/Package.swift', 'mise.toml')`와 `runner.os`, `runner.arch`. Firebase 체크아웃이 가장 오래 걸린다 |
| mise 설치 범위 | 두 잡 모두 `mise.toml` 전체 | 두 잡이 같은 mise 캐시 키를 쓰므로 한쪽이 일부만 설치해 저장하면 다른 쪽이 불완전한 캐시를 받는다 |
| 트리거 | `pull_request`, `push: branches: [main]`, `workflow_dispatch` | `main` 직접 커밋은 훅이 막으므로 PR이 기본 흐름이다 |
| 동시성 | `group: ci-${{ github.ref }}`, `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` | 같은 PR에 새 커밋이 오면 이전 실행을 취소한다. `main`은 취소하지 않는다 |
| 권한 | `permissions: contents: read` | 쓰기 권한이 필요한 스텝이 없다 |
| 타임아웃 | `lint` 20분, `build-test` 60분 | preview 러너가 멈췄을 때 무한 대기를 막는다. 첫 실행(캐시 없음)의 실제 시간을 보고 조정한다 |
| 액션 갱신 | 액션은 SHA 고정, Dependabot `github-actions` 생태계로 월 1회 한 PR에 묶어 갱신 (1라운드 리뷰 R1-7, 사용자 선택) | SHA 고정만 하면 보안 수정과 Node 런타임 폐기 대응이 멈춘다. 묶음·월 1회로 PR 소음과 macOS 러너 비용을 줄인다. SPM·mise 도구 갱신은 범위 밖 |

## 변경 계획

### 1. 로컬에서 CI 명령 재현
- 파일: 없음(위반이 나오면 해당 소스 파일)
- 변경: CI가 돌릴 명령을 저장소 루트에서 그대로 돌린다.
  ```bash
  mise exec -- swiftformat --lint .
  mise exec -- swiftlint lint --quiet
  Scripts/openapi-generate.sh --check
  ./.claude/scripts/xcbuild.sh test
  ./.claude/scripts/xcbuild.sh build -configuration Release
  ```
  위반이 나오면 코드를 고쳐 `style:`/`fix:` 커밋 하나로 남긴다. 규칙 억제로 넘기지 않는다. 위반이 없으면 커밋 없이 다음 단계로 간다.
- 검증: 다섯 명령이 모두 종료 코드 0.

### 2. `lint` 잡 추가
- 파일: `.github/workflows/ci.yml`(새 파일)
- 변경: 워크플로 뼈대(`name: CI`, 트리거, `permissions`, `concurrency`)와 `lint` 잡.
  - `runs-on: ${{ vars.MACOS_RUNNER || 'xcode-27' }}`, `timeout-minutes: 20`
  - 스텝: checkout → `jdx/mise-action@v4` → `swiftformat --lint .` → `swiftlint lint --quiet` → `Scripts/openapi-generate.sh --check`
  - 각 스텝에 `name`을 한국어로 붙여 실패 지점이 체크 목록에서 바로 보이게 한다.
  - 파일 상단 주석: 러너 변수, Xcode 메이저를 올릴 때 `Tuist.swift`와 함께 기본 라벨을 바꿔야 한다는 점.
- 검증: YAML 문법 검사. `actionlint`가 있으면 `mise x actionlint@latest -- actionlint`로 돌린다(`mise.toml`에는 추가하지 않는다). 없으면 `ruby -ryaml -e 'YAML.load_file(ARGV[0])' .github/workflows/ci.yml`.

### 3. `build-test` 잡 추가
- 파일: `.github/workflows/ci.yml`
- 변경: `lint`와 병렬인 `build-test` 잡.
  - `runs-on` 동일, `timeout-minutes: 60`
  - 스텝:
    1. checkout
    2. `jdx/mise-action@v4`
    3. `xcodebuild -version` (로그에 실제 Xcode 버전을 남긴다)
    4. `actions/cache`: `path: Tuist/.build`, 키는 결정 사항대로. `restore-keys`로 같은 OS·아키텍처의 이전 캐시를 폴백
    5. `tuist install`
    6. `tuist generate --no-open`
    7. `./.claude/scripts/xcbuild.sh test -resultBundlePath "$RUNNER_TEMP/TestResults.xcresult"`
    8. `./.claude/scripts/xcbuild.sh build -configuration Release`
    9. `if: failure()` 일 때 `actions/upload-artifact`로 `$RUNNER_TEMP/TestResults.xcresult` 업로드. `if-no-files-found: ignore`(테스트 전 단계에서 실패하면 번들이 없다), `retention-days: 7`
  - Release 빌드가 테스트 다음인 이유를 주석으로 남긴다(테스트가 더 자주 깨지고, 실패 시 번들을 먼저 확보한다).
- 검증: 2단계와 같은 YAML 검사. 로컬에서 `rm -rf *.xcworkspace App/*.xcodeproj` 없이도 `tuist install && tuist generate --no-open`이 성공하는지 확인(이미 1단계에서 통과했으면 생략 가능).

### 4. `xcbuild.sh`에 GitHub Actions 렌더러 분기
- 파일: `.claude/scripts/xcbuild.sh` (`run_xcodebuild`의 xcbeautify 호출부)
- 변경: `GITHUB_ACTIONS=true`이면 xcbeautify 인자에 `--renderer github-actions`를 더한다. 인자를 배열로 모아 기존 `--quiet --disable-logging --disable-colored-output`과 합친다. 분기 이유를 기존 주석 톤으로 한 줄 남긴다.
- 검증:
  - 로컬: `./.claude/scripts/xcbuild.sh build` 출력이 이전과 같다.
  - `GITHUB_ACTIONS=true ./.claude/scripts/xcbuild.sh build`가 `::error`/`::warning` 형식을 내는지(일부러 에러를 만들 필요는 없다. 성공 시 출력이 깨지지 않는지만 본다).
  - `xcbeautify --help`에 `--renderer`가 없으면 이 단계를 건너뛰고 README에 적지 않는다.

### 5. README 갱신
- 파일: `README.md`
- 변경:
  - 새 절 `## CI`(`## 스킴` 뒤 또는 `## 코드 스타일` 앞): 두 잡이 무엇을 검사하는지, 로컬 재현 명령(1단계의 다섯 줄), 실패 시 `.xcresult` 아티팩트 위치, 러너 변수 `MACOS_RUNNER`, 브랜치 보호에서 `lint`·`build-test`를 required check로 거는 것을 권장.
  - `## 새 앱으로 복제할 때 바꿀 곳`: 워크플로는 바꿀 곳이 없다는 한 줄(이름은 `xcbuild.sh`에서 읽는다).
  - Xcode 메이저를 올릴 때: `Tuist.swift`의 `compatibleXcodeVersions`와 `ci.yml`의 기본 러너 라벨(또는 `MACOS_RUNNER`)을 함께 바꾼다.
- 검증: 문서의 명령이 1단계에서 실제로 돌린 것과 같다.

### 5a. Dependabot으로 액션 갱신 (1라운드 리뷰 R1-7에서 추가)
- 파일: `.github/dependabot.yml`(새 파일), `README.md`(CI 절의 SHA 고정 설명)
- 변경: `package-ecosystem: github-actions`, `directory: /`, `schedule.interval: monthly`, 모든 액션을 한 그룹으로 묶는다.
  커밋 메시지 접두어는 저장소 관례(`ci`)에 맞춘다. SPM(`Tuist/Package.swift`)과 `mise.toml`은 넣지 않는다.
- 검증: YAML 문법 검사. 스키마 검증은 원격(푸시 후 저장소 Insights → Dependency graph → Dependabot)에서 한다.

### 6. 원격 검증
- 파일: 없음(실패하면 `ci.yml` 수정 커밋)
- 변경: 작업 브랜치를 푸시하고 PR을 연다. **푸시와 PR 생성은 외부 공개 동작이라 사용자 확인을 받은 뒤 한다.**
- 검증:
  - `lint`, `build-test`가 모두 성공.
  - 두 번째 실행에서 mise 캐시와 `Tuist/.build` 캐시가 복원되는지 로그로 확인하고 소요 시간을 PR 설명에 적는다.
  - 일부러 실패하는 커밋으로 아티팩트 업로드를 확인할지는 사용자에게 묻는다(확인 후 되돌린다).

## 테스트 전략

- 새 Swift 코드가 없어 추가할 단위 테스트는 없다. 기존 테스트는 수정하지 않는다.
- 검증은 두 층이다.
  - 로컬: 1단계의 다섯 명령이 CI와 같은 결과를 낸다.
  - 원격: 6단계의 실제 실행. 성공 경로, 캐시 적중 경로를 본다. 실패 경로(아티팩트 업로드, 인라인 주석)는 사용자가 원하면 일부러 깨는 커밋으로 본다.
- `openapi-generate.sh --check`의 실패 경로는 이미 스크립트에 있으므로 따로 만들지 않는다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| `xcode-27` preview 러너 대기열이 길거나 이미지가 바뀜 | 중 | `MACOS_RUNNER` 변수로 즉시 교체. GA 라벨이 나오면 기본값을 바꾼다. README에 적는다 |
| mise의 `spm:` 백엔드가 swift-openapi-generator를 소스 빌드하느라 첫 실행이 느림 | 높음 | mise-action 캐시(기본 on). 첫 실행 시간을 6단계에서 기록한다 |
| mise-action이 도구를 PATH에 올리지 않음 | 낮음 | 스텝을 `mise exec --`로 감싼다 |
| Firebase 때문에 `tuist install`·빌드가 오래 걸려 60분 초과 | 중 | `Tuist/.build` 캐시. 실제 시간을 보고 타임아웃 조정. 그래도 넘으면 `xcode-27-xlarge` 검토(유료) |
| 러너의 시뮬레이터(iOS 27)에서만 깨지는 테스트(스냅샷 기준 이미지, 로캘·시간대) | 중 | 로컬 기기와 러너 기기가 다르면 스냅샷이 어긋날 수 있다. 깨지면 이 계획 범위 밖으로 떼어 따로 다룬다(기준 이미지를 CI 기기로 맞출지 결정 필요) |
| Swift Testing 병렬 실행으로 인한 CI 전용 플레이키 테스트 | 낮음 | 재현되면 해당 테스트를 고친다. `-parallel-testing-enabled NO` 같은 전역 우회는 쓰지 않는다 |
| `xcbeautify`가 이미지에 없음 | 낮음 | `xcbuild.sh`가 폴백한다. 로그가 길어지고 4단계의 렌더러 효과가 없다. 필요하면 `mise.toml`에 xcbeautify를 추가하는 후속 결정 |
| macOS 러너 과금 | 중 | 비공개 저장소는 분당 과금 배수가 크다(정확한 배수는 미확인). `concurrency`로 중복 실행을 취소한다. README에 비용을 언급한다 |
| `swiftformat --lint .`가 로컬의 `.claude/worktrees/` 안 Swift 파일까지 검사 | 낮음(로컬만) | CI에는 해당 디렉터리가 없다. 로컬 재현 때 worktree가 있으면 결과가 다를 수 있음을 README에 적지 않고 1단계에서만 주의한다 |

## 롤백

- 워크플로만 되돌리려면 `.github/workflows/ci.yml`을 삭제하는 커밋 하나. 저장소의 다른 코드는 워크플로에 의존하지 않는다.
- 4단계(`xcbuild.sh` 렌더러 분기)는 `GITHUB_ACTIONS`가 없으면 동작이 바뀌지 않으므로 독립적으로 되돌릴 수 있다(`git revert <커밋>`).
- README 변경은 문서 커밋 revert.
- Dependabot은 `.github/dependabot.yml`을 삭제하면 멈춘다. 워크플로와 독립적이다.
- 브랜치 보호에서 required check를 걸었다면 워크플로를 지우기 전에 먼저 해제해야 PR이 막히지 않는다.
