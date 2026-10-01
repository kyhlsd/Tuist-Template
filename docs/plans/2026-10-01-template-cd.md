# 템플릿용 CD: develop/main 브랜치 모델과 TestFlight 자동 배포

## 목표

- 브랜치 모델: `feature/*` → `develop` PR → (출시) `develop` → `main` PR. 급한 수정은 `hotfix/*` → `main`.
- `main` 푸시 시 `deploy.yml` 이 Release 구성을 cloud signing 으로 아카이브해 TestFlight 에 올리고
  `v<MARKETING_VERSION>-<빌드 번호>` 태그를 단다. 심사 제출은 사람이 한다.
- `workflow_dispatch` 로 Staging(`.stg`) 빌드를 내부 TestFlight 에 올릴 수 있다.
- 배포 시크릿이 하나도 없으면 배포 잡은 **건너뜀(성공)** 으로 끝난다. 일부만 있으면 빠진 이름을 대며 실패한다.
- `main` 푸시 후 `main` 이 `develop` 에 들어가 있지 않으면 `main` → `develop` 역머지 PR 이 자동으로 열린다.
- `main` 대상 PR(출시·hotfix PR)에서 서명 없는 Release 아카이브가 돈다.
- 새 파일에 앱 이름이 박혀 있지 않아 `Scripts/rename.sh` 후에도 그대로 동작한다.
- README 에 브랜치·배포 절차와 "배포를 켜기 전" 체크리스트가 있다.

## 범위 밖

- App Store 심사 자동 제출, 외부 테스터 그룹 배포, 릴리스 노트·체인지로그 생성.
- fastlane / match 도입(README 에 전환 경로만 한 단락).
- GitHub Environments·required reviewers(비공개 저장소는 플랜 제약이 있어 의존하지 않는다. README 에 선택 사항으로만).
- 워크플로 정적 검사(actionlint) 도입. 필요하면 별도 작업.
- 기존 `release-build` 잡이 Firebase plist 가 있을 때 Crashlytics 로 dSYM 을 올리는 동작(아래 위험 참고).
- GitHub 저장소 설정 변경(기본 브랜치, rulesets, 시크릿 등록). 사람이 README 절차로 한다. Claude 는 `git push` 가 막혀 있다.

## 전제

구현 세션은 이 문서만 읽는다.

### 저장소 사실

- 저장소는 **public**, 기본 브랜치 `main`, 원격·로컬 모두 `develop` 없음, 태그 0개.
- `.github/workflows/ci.yml:12-16` 트리거는 `pull_request`(브랜치 필터 없음), `push: [main]`, `workflow_dispatch`.
  `:24-26` concurrency 는 PR 은 ref, push 는 sha 별 그룹. `:109-126` `release-build` 는 시뮬레이터 Release 빌드.
  러너 `${{ vars.MACOS_RUNNER || 'xcode-27' }}`, 외부 액션은 SHA 고정(뒤에 버전 주석). 같은 SHA 를 재사용한다:
  - `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`
  - `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1`
- `.github/actions/setup/action.yml`: mise → SPM 캐시 → `tuist install` → `tuist generate --no-open`. 배포 잡도 이걸 쓴다.
- `.github/workflows/templates.yml:25-26` push 는 `main` 만.
- `.claude/scripts/xcbuild.sh:95-125`: build/test 만, 항상 시뮬레이터 destination. **아카이브 용도로 확장하지 않는다**
  (Claude 용 시뮬레이터 래퍼다). 아카이브는 새 `Scripts/release.sh` 가 맡는다.
- 스킴: `TuistApp`(앱, Release 로 아카이브), `TuistApp-Staging`(Staging 으로 아카이브,
  `Tuist/ProjectDescriptionHelpers/Project+Templates.swift:242-252`). 워크스페이스 스킴 `TuistApp-Workspace` 로
  아카이브하면 데모 앱까지 묶여 배포 불가(`Scheme+Workspace.swift` 주석). 워크스페이스는 `TuistApp.xcworkspace`.
- 앱 이름은 `Tuist/ProjectDescriptionHelpers/AppConstants.swift` 의 `static let appName = "..."`. `rename.sh:57-60` 이
  `perl -ne 'print $1 if /static let appName = "([^"]*)"/'` 로 읽는다. 새 스크립트도 같은 방식으로 읽어 이름을 하드코딩하지 않는다.
- 서명: `Configurations/Signing.xcconfig:12-13` `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM =`(빈 값).
  **Team ID 는 비밀이 아니라 커밋하는 값**이다(파일 주석, README "서명"). `Signing.local.xcconfig` 가 덮어쓸 수 있다.
- 버전: `Configurations/Release.xcconfig:16-17`, `Staging.xcconfig:19-20` 에 각각 `MARKETING_VERSION`,
  `CURRENT_PROJECT_VERSION`. Release 주석에 "CI 에서 빌드 번호로 덮어쓴다"고 예고만 돼 있다.
  명령줄 빌드 설정(`CURRENT_PROJECT_VERSION=N`)은 모든 타깃에 적용되므로 앱과 NotificationService 익스텐션의 번들 버전이 같아진다.
- `Configurations/ClientKeys.xcconfig` 는 gitignore(`.example` 만 커밋). Release/Staging xcconfig 가 `#include?` 로 읽는다.
  CI 에는 없다 → 시크릿에서 써 줘야 한다.
- Firebase `GoogleService-Info.plist` 는 **커밋하는 파일**이다(`Configurations/Firebase/README.md`). 시크릿 불필요.
  없으면 `Scripts/firebase-copy-config.sh` 는 번들 사본을 지우고, `Scripts/crashlytics-upload-symbols.sh:16-24` 는 경고만 남긴다.
- 앱 Info.plist 추가 키는 `App/Project.swift:76` `additionalInfoPlist:` 딕셔너리.
- `.claude/hooks/guard-git.sh:31-38`: 직접 커밋 차단 대상은 `origin/HEAD` 가 가리키는 기본 브랜치 + `main`/`master`.
  기본 브랜치를 `develop` 으로 바꾸면 `develop`·`main` 둘 다 막힌다. **수정 불필요.**
- Renovate·Dependabot 은 기본 브랜치를 대상으로 PR 을 연다. 기본 브랜치를 `develop` 으로 바꾸면 따로 설정할 것 없음.
- `rename.sh` 는 git 이 추적하는 텍스트 파일 전부를 치환한다. 새 파일에 앱 이름을 쓰지 않으면 치환 대상도 아니다.
- 로컬 Xcode 27.0, 로컬 시뮬레이터 iOS 26 / CI iOS 27. mise 로 tuist 4.208.0 고정. shellcheck·actionlint 없음.

### 플랫폼 사실

- ASC API 키 인증: `xcodebuild -allowProvisioningUpdates -authenticationKeyPath <p8> -authenticationKeyID <id>
  -authenticationKeyIssuerID <issuer>` (Xcode 13+). 자동 서명이 인증서·프로필을 만든다(cloud signing).
  출처: https://developer.apple.com/videos/play/wwdc2021/10204/
- `xcodebuild -exportArchive` 의 ExportOptions(로컬 Xcode 27 `xcodebuild -help` 로 확인):
  `method=app-store-connect`(`app-store` 는 deprecated), `destination=upload`(export 와 업로드를 한 번에),
  `teamID`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber`(기본 YES → **NO 로 둔다**),
  `testFlightInternalTestingOnly`(YES 면 App Store 제출 불가), `uploadSymbols`.
  처음 도입된 Xcode 버전은 미확인. 이 템플릿은 Xcode 27 고정이라 상관없다.
- 아카이브 destination: `-destination 'generic/platform=iOS'`.
- `ITSAppUsesNonExemptEncryption` 을 Info.plist 에 두면 업로드마다 수출 규정 질문이 뜨지 않는다.
- GitHub:
  - `GITHUB_TOKEN` 으로 만든 PR·태그 푸시는 다른 워크플로를 트리거하지 않는다.
  - `GITHUB_TOKEN` 으로 PR 을 만들려면 저장소 설정 "Allow GitHub Actions to create and approve pull requests" 가 켜져 있어야 한다(기본 꺼짐).
  - 같은 concurrency 그룹에서는 대기 중인 실행이 하나만 남고, 새 실행이 오면 이전 대기 실행은 취소된다.
  - 건너뛴(skipped) 잡은 required check 를 만족한다.
- GitHub Environments 의 required reviewers 는 public 저장소면 모든 플랜에서 되지만, 비공개 저장소는 플랜 제약이 있다
  (https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments). 템플릿 사용자는
  비공개일 수 있으므로 의존하지 않는다.
- macOS 러너는 비공개 저장소에서 분당 과금 배수가 크다. 이 저장소는 public 이라 무료다.

### 조사 간 충돌과 처리

| 플랫폼 조사 | 저장소 사실 | 처리 |
|---|---|---|
| develop 없이 trunk + 태그 배포 권장 | 출시하지 않을 기능을 기능 플래그 없이 격리해야 하고, 사용자가 develop 모델을 정함 | develop/main 채택 |
| `DEVELOPMENT_TEAM` 을 시크릿으로 | Team ID 는 커밋하는 값이라고 문서화돼 있음 | 시크릿으로 받지 않고 `Signing.xcconfig` 값을 읽는다. 비어 있으면 preflight 가 실패 |
| Firebase plist 를 시크릿에서 복원 | plist 는 커밋하는 파일 | 시크릿 없음 |
| 빌드 번호는 Xcode 가 업로드 시 관리 | 태그에 빌드 번호를 넣으려면 빌드 전에 번호를 알아야 함 | `run_number + BUILD_NUMBER_OFFSET`, `manageAppVersionAndBuildNumber=NO` |
| Environments required reviewers 는 Enterprise 전용 | 이 저장소는 public 이라 실제로는 쓸 수 있음 | 템플릿은 비공개일 수 있어 의존하지 않음. README 에 선택 사항으로 |

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 브랜치 모델 | `develop`(기본 브랜치) + `main`(출시) + `feature/*` + `hotfix/*` | 출시 시점 선택과 TestFlight 빌드 수를 기능 플래그 없이 통제 |
| 기본 브랜치 | `develop` | 사람·봇 PR 이 자동으로 develop 을 향함. guard-git.sh 가 둘 다 보호 |
| 서명 | `xcodebuild` + ASC API 키 cloud signing | 새 의존성 없음(mise·Tuist 만), 사용자가 할 일은 시크릿 3개 + Team ID 커밋 |
| 배포 로직 위치 | `Scripts/release.sh`(서브커맨드), 워크플로는 얇게 | 로컬 재현, CI 이식성, 이름 하드코딩 방지 |
| 빌드 번호 | `github.run_number + vars.BUILD_NUMBER_OFFSET(기본 0)` | 빌드 전에 알 수 있어 태그·로그가 일치. 저장소 이전 시 오프셋만 올림 |
| 마케팅 버전 출처 | `Configurations/Release.xcconfig` 의 `MARKETING_VERSION` | 기존 위치 유지. Staging 은 Staging.xcconfig 값 |
| Release TestFlight | `testFlightInternalTestingOnly=NO` | 같은 빌드를 심사에 제출할 수 있어야 함 |
| Staging TestFlight | `workflow_dispatch`, `testFlightInternalTestingOnly=YES` | QA 전용. 별도 ASC 앱(`.stg`) 필요 |
| 태그 | Release 만 `v<버전>-<빌드>` | 같은 버전 재업로드도 태그가 겹치지 않음 |
| 시크릿 미설정 | ASC 3개 모두 없으면 skip(성공 + 요약), 일부만 있으면 실패 | 새 템플릿 저장소의 CI 가 처음부터 초록. 오설정은 숨기지 않음 |
| ClientKeys 시크릿 없음 | 경고(`::warning`) 후 진행 | 키를 안 쓰는 앱도 있음. 기존 CI 와 같은 동작 |
| 역머지 | `main` 푸시마다 필요하면 `main`→`develop` PR 생성(GITHUB_TOKEN) | 사람이 잊기 쉬움. PR head 가 main 의 SHA 라 push CI 결과가 그대로 required check 를 채움 |
| 출시 PR 검사 | `main` 대상 PR 에서만 `CODE_SIGNING_ALLOWED=NO` Release 아카이브 | 아카이브·스킴 문제를 머지 전에 잡음. 시크릿 불필요 |
| 배포 동시성 | 워크플로 최상위 그룹 `deploy-Staging`(수동 Staging) / `deploy-Release-<ref>`(그 외), `cancel-in-progress: false` | 업로드 중 취소 방지. 대기 중 실행이 최신으로 대체되는 건 허용(최신 main 만 올라가면 됨). 리뷰 결정 R1-1, R2-1(`docs/reviews/feat-template-cd.md`) |
| Environments | 쓰지 않음 | 플랜 의존 제거 |

## 변경 계획

각 단계는 독립적으로 빌드·CI 가 통과하고 커밋 하나 분량이다.
작업 브랜치: `feat/template-cd` (base `main`. 이 시점엔 develop 이 없다).

### 1. 수출 규정 Info.plist 키

- 파일: `App/Project.swift`
- 변경: `additionalInfoPlist` 에 `"ITSAppUsesNonExemptEncryption": false` 추가. 주석: "HTTPS 등 OS 제공 암호화만 쓰면 면제다.
  자체 암호화를 넣으면 true 로 바꾸고 App Store Connect 에 수출 규정 문서를 낸다." README 체크리스트에서 이 줄을 가리킨다.
- 검증: `tuist generate --no-open` → `./.claude/scripts/xcbuild.sh build` 통과. 빌드된 앱의 Info.plist 를
  `plutil -extract ITSAppUsesNonExemptEncryption raw` 로 읽어 `false`. `./.claude/scripts/xcbuild.sh test -only-testing:TuistAppTests` 통과.

### 2. `Scripts/release.sh` (preflight / write-secrets / archive / upload)

- 파일: `Scripts/release.sh`(새 파일, 실행 권한), `Scripts/crashlytics-upload-symbols.sh` 는 건드리지 않는다.
- 변경: `set -euo pipefail`, 기존 스크립트 스타일(헤더 주석에 용법, `die`, 한국어 주석). 서브커맨드:
  - `preflight`
    - 환경변수 `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` 를 본다.
    - 셋 다 비면 `configured=false` 를 출력하고 exit 0. `GITHUB_OUTPUT` 이 있으면 거기에도 쓴다.
    - 일부만 있으면 빠진 이름을 나열하고 exit 1.
    - 셋 다 있으면 `Signing.xcconfig` 의 `DEVELOPMENT_TEAM` 을 읽는다(`Signing.local.xcconfig` 는 CI 에 없으니 보지 않는다).
      비어 있으면 "Team ID 를 커밋하라" 며 exit 1.
    - `configured=true`, `team_id=<값>` 을 출력한다.
  - `write-secrets`
    - `ASC_KEY_P8`(PEM 원문)을 `${RUNNER_TEMP:-$TMPDIR}/AuthKey_<id>.p8` 에 `umask 077` 로 쓰고 경로를 출력한다.
    - `CLIENT_KEYS_XCCONFIG` 가 있으면 `Configurations/ClientKeys.xcconfig` 에 쓴다.
    - 없고 파일도 없으면 `::warning::`(GitHub Actions 일 때) 또는 stderr 경고.
    - 로컬에 이미 파일이 있으면 덮어쓰지 않는다(로컬 실행 보호).
  - `archive <Release|Staging> [--unsigned]`
    - 스킴은 AppConstants 의 appName 으로 정한다: Release → `<appName>`, Staging → `<appName>-Staging`.
      워크스페이스는 `<appName>.xcworkspace`.
    - `xcodebuild archive -workspace … -scheme … -configuration <구성> -destination 'generic/platform=iOS'
      -archivePath "$ARCHIVE_PATH"` 를 실행한다. `ARCHIVE_PATH` 기본값은 `${RUNNER_TEMP:-$TMPDIR}/<appName>-<구성>.xcarchive`.
    - `BUILD_NUMBER` 가 있으면 `CURRENT_PROJECT_VERSION=$BUILD_NUMBER` 를 넘긴다. 서명 아카이브인데 없으면 die.
    - `--unsigned` 면 `CODE_SIGNING_ALLOWED=NO`, 아니면 `-allowProvisioningUpdates` + 인증 플래그 3개
      (`ASC_KEY_PATH`, `ASC_KEY_ID`, `ASC_ISSUER_ID`).
    - xcbeautify 가 있으면 xcbuild.sh 와 같은 방식으로 파이프한다. github-actions renderer 판별 로직도 같다.
  - `upload <Release|Staging>`
    - `PlistBuddy` 로 임시 ExportOptions.plist 를 만든다:
      `method=app-store-connect`, `destination=upload`, `teamID=<preflight 값 또는 TEAM_ID env>`,
      `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`,
      `testFlightInternalTestingOnly`(Staging true, Release false).
    - `xcodebuild -exportArchive -archivePath … -exportOptionsPlist … -exportPath <tmp> -allowProvisioningUpdates` + 인증 플래그.
  - `version <Release|Staging>`: 해당 xcconfig 의 `MARKETING_VERSION` 을 perl 로 읽어 출력한다(태그용).
- 검증(로컬, 시크릿 없이):
  - `bash -n Scripts/release.sh`
  - `env -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_KEY_P8 Scripts/release.sh preflight` → `configured=false`, exit 0
  - `ASC_KEY_ID=x Scripts/release.sh preflight` → 빠진 두 이름이 나오고 exit 1
  - 셋 다 더미 + 빈 Team ID → Team ID 메시지, exit 1
  - `Scripts/release.sh version Release` → `1.0.0`
  - `BUILD_NUMBER=7 Scripts/release.sh archive Release --unsigned` 성공. `.xcarchive` 안 앱과
    `PlugIns/*.appex` 의 Info.plist `CFBundleVersion` 이 둘 다 `7`, `CFBundleShortVersionString` 이 `1.0.0`
  - `BUILD_NUMBER=7 Scripts/release.sh archive Staging --unsigned` 성공. 번들 ID 가 `.stg` 로 끝난다
  - `grep -c TuistApp Scripts/release.sh` → 0
  - `upload` 는 실제 키가 필요하다. 구현 중 확인 불가 → 6단계 이후 사람이 첫 배포로 확인

### 3. CI: develop 트리거와 출시 PR 아카이브 잡

- 파일: `.github/workflows/ci.yml`, `.github/workflows/templates.yml`
- 변경:
  - `ci.yml` `push.branches: [main, develop]`. 헤더 주석의 "PR 과 main 푸시" 문구를 develop 포함으로 고친다.
    concurrency 는 그대로(sha 별이라 브랜치가 늘어도 맞음).
  - 새 잡 `release-archive`:
    - `if: github.event_name == 'pull_request' && github.base_ref == 'main'`
    - 체크아웃 → 셋업 → `BUILD_NUMBER=0 Scripts/release.sh archive Release --unsigned`. `timeout-minutes: 30`.
    - 주석: 출시·hotfix PR 에서만 돈다. 다른 PR 에서는 skipped 라 required 로 걸어도 막히지 않는다.
  - `templates.yml` push `branches: [main, develop]`.
- 검증: YAML 구문 검사(`ruby -ryaml -e 'YAML.load_file(ARGV[0])'` 등. 쓸 수 있는 파서는 구현 중 확인).
  실제 동작은 이 브랜치의 PR(base main)에서 `release-archive` 가 실행되고 통과하는지로 확인한다.

### 4. 배포 워크플로 `deploy.yml`

- 파일: `.github/workflows/deploy.yml`(새 파일)
- 변경:
  - 트리거: `push: branches: [main]`, `workflow_dispatch` (input `configuration`: choice `Staging`/`Release`, 기본 `Staging`).
  - `permissions: contents: read`(최상위), deploy 잡만 `contents: write`(태그).
  - 잡 `preflight`:
    - `runs-on: ubuntu-latest`. perl·bash 만 쓴다.
    - 체크아웃 → `Scripts/release.sh preflight`(env 로 시크릿 주입) → outputs `configured`, `team_id`, `configuration`.
    - `configuration` 결정: push 면 Release, dispatch 면 input.
    - dispatch 로 Release 를 고른 경우 `github.ref` 가 `refs/heads/main` 이 아니면 실패한다(main 밖 Release 배포 금지).
    - 미설정이면 `$GITHUB_STEP_SUMMARY` 에 "배포 시크릿이 없어 건너뜀. README '배포를 켜기 전'" 을 쓰고
      `::notice::` 도 남긴다.
  - 잡 `deploy`:
    - `needs: preflight`, `if: needs.preflight.outputs.configured == 'true'`.
    - 러너는 ci.yml 과 같은 식, `timeout-minutes: 60`.
    - concurrency 는 잡이 아니라 워크플로 최상위에 둔다(위 결정 표 "배포 동시성", 리뷰 결정 R1-1, R2-1).
    - 스텝:
      1. 체크아웃
      2. 셋업
      3. `write-secrets`(출력 경로를 `ASC_KEY_PATH` 로)
      4. `BUILD_NUMBER=$(( github.run_number + ${BUILD_NUMBER_OFFSET:-0} ))`. `vars.BUILD_NUMBER_OFFSET` 사용
      5. `archive`
      6. `upload`
      7. Release 면 `git tag v<version>-<build>` 후 `git push origin <tag>`
      8. 잡 요약에 구성·버전·빌드 번호·커밋을 쓴다
    - p8 파일은 `if: always()` 스텝으로 지운다.
  - 헤더 주석:
    - 트리거와 skip 규칙
    - 빌드 번호 규칙
    - 동시성 선택 이유: ci.yml 과 달리 대기 실행 대체를 허용한다
    - GITHUB_TOKEN 태그 푸시는 다른 워크플로를 트리거하지 않는다
- 검증: 이 단계 커밋이 main 에 머지되면 시크릿이 없으므로 `preflight` 성공 + `deploy` skipped, 요약 문구가 보여야 한다.
  머지 전에는 YAML 구문 검사만. 실제 업로드는 사람이 시크릿 등록 후 확인(아래 "머지 후 사람이 할 일").

### 5. 역머지 워크플로 `back-merge.yml`

- 파일: `.github/workflows/back-merge.yml`(새 파일)
- 변경:
  - `on: push: branches: [main]`. `permissions: contents: read, pull-requests: write`. `runs-on: ubuntu-latest`.
  - 스텝:
    1. 체크아웃(`fetch-depth: 0`)
    2. `origin/develop` 이 없으면 notice 후 종료(템플릿 직후 상태)
    3. `git merge-base --is-ancestor origin/main origin/develop` 이면 종료
    4. `gh pr list --base develop --head main --state open` 이 비어 있지 않으면 종료
    5. `gh pr create --base develop --head main --title "chore: main 을 develop 에 역머지" --body <본문>`
  - 본문에 적을 것:
    - merge commit 으로 머지할 것(squash 금지)
    - 충돌이 나면 `git switch -c chore/back-merge develop && git merge origin/main` 으로 따로 PR
  - PR 생성이 권한 문제로 실패하면 README 의 "Allow GitHub Actions to create and approve pull requests" 설정을
    가리키는 `::error::` 를 남기고 실패한다.
  - 주석: GITHUB_TOKEN PR 은 CI 를 새로 트리거하지 않지만, head 가 main 의 SHA 라 main push 때의 CI 결과가 그 SHA 에 붙어 있다.
- 검증: YAML 구문 검사. main 머지 직후 develop 이 없으므로 "develop 없음" notice 로 끝나는지 확인.
  PR 이 실제로 열리는지는 develop 생성 후 첫 hotfix/출시 때 확인.
  head SHA 의 push 체크가 required check 로 인정되는지는 구현 중 확인 → 안 되면 README 에 "역머지 PR 에서 CI 수동 실행" 을 적는다.

### 6. 문서

- 파일: `README.md`, `CLAUDE.md`, `Scripts/rename.sh`(헤더 주석만 필요 시)
- 변경:
  - README 새 섹션 `## 브랜치와 배포`(`## CI` 앞)
    - 브랜치 표: feature/hotfix/develop/main 각각의 출발점·PR 대상·머지 방식.
      `develop`→`main` 은 merge commit, 기능 PR 은 squash 가능.
    - 이벤트별 워크플로 표: PR, develop 푸시, main 대상 PR, main 푸시, 수동 실행.
    - 빌드 번호·태그 규칙, `MARKETING_VERSION` 올리는 시점: 출시 PR 전에 develop 에서. 이미 출시된 버전이면 업로드가 거절된다.
    - 시크릿 미설정 시 동작.
    - develop 없이 쓰려면: back-merge.yml 을 지우고, 기본 브랜치를 main 으로 두고, 기능 PR 을 main 으로 보낸다.
      그러면 main 머지마다 TestFlight 에 올라간다.
    - fastlane match 로 바꾸려면: 한 단락.
    - Environments(required reviewers)는 플랜이 되면 deploy 잡에 `environment:` 를 추가하는 선택 사항.
  - README `## CI`:
    - 트리거에 develop 추가.
    - `release-archive` 잡 행 추가.
    - required check 권장 목록에 `release-archive` 추가.
  - README "복제한 뒤 직접 할 일"에 **배포를 켜기 전** 블록 추가:
    1. `develop` 생성 후 푸시, GitHub 기본 브랜치를 `develop` 으로 변경
    2. rulesets 설정
       - `main`·`develop`: PR 필수 + required checks
       - `main`: merge commit 허용
       - 태그 `v*`: 삭제·갱신 금지
    3. Settings > Actions 에서 "Allow GitHub Actions to create and approve pull requests" 켜기
    4. Team ID 커밋
    5. App Store Connect 에 Release 앱 등록(Staging 을 쓰면 `.stg` 앱도), App ID 의 Push 기능 확인
    6. ASC API 키 발급. 역할은 Admin 권장, 최소 역할은 미확인이라고 명시
    7. 저장소 시크릿 등록: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`(p8 파일 원문), `CLIENT_KEYS_XCCONFIG`(선택)
    8. 저장소 변수 등록: `BUILD_NUMBER_OFFSET`(선택. 기존 앱이면 ASC 의 최신 빌드 번호 이상)
    9. `App/Project.swift` 의 `ITSAppUsesNonExemptEncryption` 확인
    10. 첫 배포는 Actions > Deploy 를 Staging 으로 수동 실행해 확인
  - 기존 "QA 배포(Staging)를 하기 전"의 "아카이브는 `TuistApp-Staging` 스킴" 항목을 수동 배포 워크플로로 바꾼다.
  - "`.github/workflows/ci.yml` … 바꿀 곳이 없다" 문단에 deploy.yml·back-merge.yml·release.sh 도 이름을 쓰지 않는다고 추가한다.
  - CLAUDE.md "작업 흐름" 끝에 한 줄: "기능 브랜치는 `develop` 에서 따고 `develop` 으로 PR 한다
    (hotfix 만 `main`). 자세한 건 README '브랜치와 배포'."
- 검증:
  - README 의 경로·잡 이름·시크릿 이름이 워크플로·스크립트와 일치하는지 grep 으로 대조한다.
  - 템플릿 무결성: 임시 클론(`git clone . "$tmp"`)에서 `Scripts/rename.sh Sample com.example` 을 실행한다.
    이어서 `tuist install && tuist generate --no-open` 후 `BUILD_NUMBER=1 Scripts/release.sh archive Release --unsigned` 가 통과하고,
    `Scripts/release.sh preflight` 가 skip 하는지 확인한다.

## 테스트 전략

- Swift 단위 테스트 추가 없음. 앱 코드 변경은 Info.plist 키 하나뿐이고 manifest 에서 넣는다.
  기존 `TuistAppTests`·`PrivacyManifestTests` 가 계속 통과하는지만 확인한다.
- 스크립트 분기 검증은 2단계 표대로 수동으로 한다:
  - preflight: 미설정, 부분 설정, Team ID 누락, 정상
  - archive: Release·Staging, 빌드 번호 주입, 앱·익스텐션 버전 일치
  - version 출력
- 워크플로 분기는 GitHub 에서 확인한다:
  - 이 PR(base main): `release-archive` 실행
  - main 머지 후: deploy skip 과 back-merge 의 "develop 없음"
  - 시크릿 등록 후: Staging 수동 배포, 출시 PR 머지 시 Release 배포와 태그, hotfix 머지 시 역머지 PR
- rename 후 동작은 6단계 임시 클론 검증으로 확인한다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| ASC 키 역할이 부족해 cloud signing 이 인증서·프로필을 못 만듦 | 중 | README 에 Admin 권장. 첫 Staging 수동 배포로 조기 확인. 실패 로그를 보고 문구 갱신 |
| `xcode-27` preview 러너 불안정 | 중 | 기존처럼 `vars.MACOS_RUNNER` 로 교체 가능. 배포 잡도 같은 식 사용 |
| `MARKETING_VERSION` 을 안 올려 이미 출시된 버전으로 업로드 → 거절 | 중 | README 에 올리는 시점 명시. 실패는 upload 스텝 로그로 드러남 |
| run_number 가 리셋(워크플로 파일 재생성·저장소 이전)되어 빌드 번호 중복 | 낮 | `BUILD_NUMBER_OFFSET` 변수. README 에 안내 |
| 역머지 PR 이 Actions 권한 설정이 꺼져 있어 생성 실패 | 중 | 실패 메시지에 설정 경로. README 체크리스트 |
| head SHA 의 push 체크가 역머지 PR 의 required check 로 인정되지 않음 | 낮 | 5단계 "구현 중 확인". 안 되면 수동 실행 안내 |
| 같은 구성 배포가 연달아 오면 대기 실행이 최신으로 대체되어 중간 커밋은 안 올라감 | 확정 동작 | 의도한 것(최신 main 만 의미 있음). 주석에 명시 |
| Firebase plist 가 있는 앱에서 `release-archive`(그리고 기존 `release-build`)가 PR 마다 dSYM 을 Crashlytics 에 올림 | 중 | 기존 동작과 같아 이번 범위 밖. 별도 작업 후보로 README 에 한 줄 |
| `ITSAppUsesNonExemptEncryption=false` 가 자체 암호화를 쓰는 앱에서 틀린 신고가 됨 | 낮 | manifest 주석과 README 체크리스트에 확인 항목 |
| public 저장소에서 시크릿 노출 | 낮 | 배포는 `push`·`workflow_dispatch` 만(포크 PR 에서는 시크릿 없음). `pull_request_target` 쓰지 않음. p8 은 `always()` 로 삭제 |

## 롤백

- 코드: 단계별 커밋이라 해당 커밋 `git revert`. deploy.yml·back-merge.yml 은 파일 삭제만으로 꺼진다.
- 배포만 멈추려면: 시크릿 `ASC_KEY_ID` 등을 지우면 preflight 가 skip 한다(코드 변경 불필요).
- 브랜치 모델 되돌리기: GitHub 기본 브랜치를 `main` 으로, back-merge.yml 삭제, ci.yml·templates.yml 의 develop 트리거 제거,
  CLAUDE.md 한 줄 삭제.
- TestFlight 에 올라간 빌드는 되돌릴 수 없다(만료 90일 또는 ASC 에서 테스트 중지). 태그는 `git push --delete origin <tag>`.

## 머지 후 사람이 할 일

README "배포를 켜기 전" 체크리스트와 같다.
순서: develop 생성·기본 브랜치 변경 → rulesets → Actions PR 권한 → Team ID 커밋(develop 경유) → ASC 앱·키 → 시크릿 →
Staging 수동 배포 → 첫 출시 PR.
