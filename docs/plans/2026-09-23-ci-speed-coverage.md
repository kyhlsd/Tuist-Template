# CI 속도 개선, 커버리지 요약, PR 템플릿

## 목표

- `ci.yml`의 Release 빌드가 `build-test` 잡에서 빠져 병렬 잡 `release-build`로 돈다. PR의 크리티컬 패스는
  `max(build-test, release-build)`가 된다.
- 공통 셋업(mise → SPM 캐시 → `tuist install` → `tuist generate`)은 로컬 composite action 한 곳에만 있다.
  두 잡이 같은 셋업을 복붙하지 않는다.
- CI에서만 Xcode 컴파일 캐시(`COMPILATION_CACHE_ENABLE_CACHING=YES`)가 켜진다. CAS 디렉터리는 `actions/cache`로
  보존한다. 저장은 `main` 푸시와 `workflow_dispatch`에서만 하고, PR은 복원만 한다.
- 테스트가 통과하면 앱과 모듈의 모듈별 라인 커버리지 표가 잡 요약(`GITHUB_STEP_SUMMARY`)에 뜬다. 테스트 타깃,
  데모 앱, 외부 패키지는 표에 나오지 않는다. 커버리지로 잡을 실패시키지 않는다(게이트 없음).
- `.github/pull_request_template.md`가 생겨 새 PR 본문의 기본값이 된다.
- README의 CI 절에 새 잡 구성, 캐시, 커버리지, required check 갱신, CODEOWNERS 도입 시점이 적힌다.
- Tuist 계정·시크릿·저장소 변수가 없는 상태에서 템플릿을 복제해도 워크플로가 그대로 돈다(직전 계획의 원칙 유지).
- **측정:** 변경 전 기준(아래 "전제 > 기준 측정")과 비교해 캐시 적중 시 PR 크리티컬 패스 시간을 README 또는 이 문서에
  기록한다. 컴파일 캐시가 캐시 적중 run에서 `build-test`를 1분 이상 줄이지 못하면 3단계를 되돌린다(결정 게이트).

## 범위 밖

- Tuist 서버 기능: 원격 바이너리 캐시(`tuist cache warm`), 선택적 테스트(`tuist test --selective-testing`),
  Tuist Xcode 캐시(`tuist setup cache`). Tuist 계정과 `TUIST_TOKEN`이 필요해서 제외한다. 컴파일 캐시 효과를 잰 뒤
  후속 작업에서 다시 판단한다.
- DerivedData 전체 캐시. CAS(`CompilationCache.noindex`)만 캐시한다.
- 로컬 개발 환경에서 컴파일 캐시 켜기(`Tuist/ProjectDescriptionHelpers`의 base settings). CI 전용 인자로만 넣는다.
- 병렬 테스트(`-parallel-testing-enabled`). 테스트 실행 자체는 수 초라 효과가 거의 없고, 스냅샷 테스트와 충돌할 수 있다.
- `build-for-testing` / `test-without-building` 분리, 테스트 샤딩.
- Codecov 같은 외부 커버리지 서비스, PR 코멘트, 커버리지 최소치 게이트.
- CODEOWNERS. 커밋 작성자가 한 명(65커밋 전부)인 공개 템플릿이라 실효가 없다. README에 도입 시점만 적는다.
- Release 빌드를 `main` 푸시에서만 돌리기. `#if DEBUG` 분기 때문에 Release에서만 나는 컴파일 에러를 PR에서 놓친다.
- 브랜치 보호 설정 변경(저장소 설정이라 코드로 못 넣는다. README에 안내만 적는다).

## 전제

### 기준 측정 (2026-09-23, PR run 35834379977, 성공)
| 스텝 | 시간 |
|---|---|
| 셋업(체크아웃 + mise + SPM 캐시 복원 + `tuist install` + `tuist generate`) | 약 1분 (복원 14초, install 21초, generate 17초) |
| 테스트 | 6분 06초 (대부분 컴파일. 스위트는 밀리초 단위로 통과) |
| Release 빌드 | 2분 00초 |
| `build-test` 잡 전체 | 약 9분 08초 |
| `lint` 잡 | 약 17초 |

`xcbeautify --quiet`가 출력을 모아 찍어서 로그 타임스탬프로는 컴파일과 실행 시간을 나눌 수 없다.

### 현재 코드
- `.github/workflows/ci.yml:49-127`: `build-test` 잡. 스텝 순서는 체크아웃 → mise → `xcodebuild -version` →
  SPM 캐시 복원/설치/저장(`Tuist/.build`, 복원·저장 분리) → `tuist generate --no-open` → 테스트(`timeout-minutes: 45`,
  `-resultBundlePath "$RUNNER_TEMP/TestResults.xcresult" -test-timeouts-enabled YES -collect-test-diagnostics never`) →
  Release 빌드 → 실패 시 xcresult와 스냅샷 실패 이미지 업로드.
- 외부 액션은 커밋 SHA로 고정한다(파일 상단 주석). 새로 쓰는 액션도 같은 규칙을 따른다. 이미 쓰는 SHA:
  `actions/checkout@3d3c42e5…`(v7.0.1), `jdx/mise-action@c2a87611…`(v4.3.0),
  `actions/cache/restore`·`save@55cc8345…`(v6.1.0), `actions/upload-artifact@043fb46d…`(v7.0.1).
- 잡 타임아웃 가정(`ci.yml:87-92` 주석): 테스트 앞 스텝의 합계가 15분(잡 60분 - 스텝 45분) 안이어야 스텝
  타임아웃이 먼저 끊고 결과 업로드가 돈다. CAS 복원 시간도 이 합계에 들어간다.
- `.claude/scripts/xcbuild.sh`: `run_xcodebuild`가 추가 인자를 `"$@"`로 `xcodebuild`에 넘긴다. 그래서 빌드 설정
  `KEY=VALUE`와 `-enableCodeCoverage YES`를 스크립트 수정 없이 CI에서 붙일 수 있다. **스크립트는 바꾸지 않는다.**
- `Tuist/ProjectDescriptionHelpers/Scheme+Workspace.swift:22-38`: `TuistApp-Workspace` 스킴. 테스트 액션은
  `testAction: .targets(tests.map { .testableTarget(target: $0) })`이고 커버리지 옵션이 없다.
  `app`(`TargetReference`), `modules`(`Module.all`)가 이미 지역 변수로 있다.
- `Tuist/.build/tuist-derived/`가 있다. 즉 Tuist가 SPM 패키지(Firebase 포함)를 **Xcode 프로젝트 타깃으로 통합**한다.
  플랫폼 조사에서 나온 "Xcode 26 베타 때 SPM 패키지는 컴파일 캐시 대상이 아니었다"는 보고는 Xcode 네이티브 SPM
  통합에 대한 것이다. 이 저장소에는 해당하지 않을 가능성이 높지만 **구현 중 확인**한다(진단 remark로).
- README `## CI` 절(`README.md:94-128`): 잡 표(2행), 로컬 재현 명령, 실패 시 아티팩트, 러너, Xcode 메이저 업그레이드,
  브랜치 보호 권장(`lint`, `build-test`를 required로 걸라고 적혀 있다).
- 저장소는 공개(`kyhlsd/Tuist-Template`)라 GitHub 호스티드 macOS 러너 시간은 무료다. 잡을 하나 더 두는 비용은
  동시 실행 한도뿐이다.

### 쓰기로 한 API
| 심볼 | 도입 | 용도 | 비고 |
|---|---|---|---|
| `COMPILATION_CACHE_ENABLE_CACHING=YES` | Xcode 26 | 입력이 같은 컴파일 결과를 CAS에서 재사용 | 로컬 Xcode 27의 기본값은 미설정(=NO)이다(`-showBuildSettings`로 확인) |
| `COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES` | Xcode 26 | 캐시 적중과 누락을 로그에 남김 | 검증할 때만 켠다 |
| `COMPILATION_CACHE_CAS_PATH` | Xcode 26 | CAS 위치 | 로컬 기본값은 `~/Library/Developer/Xcode/DerivedData/CompilationCache.noindex`(프로젝트 간 공유). 러너에서도 같은지 **구현 중 확인**. 다르면 이 설정으로 경로를 고정한다 |
| `xcodebuild -enableCodeCoverage YES` | 기존 | CI에서만 커버리지 수집 | |
| `TestActionOptions.options(coverage:codeCoverageTargets:)` | Tuist 4 | 스킴에 커버리지 대상 목록 지정 | `coverage: false`로 두어 로컬 기본 동작은 바꾸지 않는다 |
| `xcrun xccov view --report --json <xcresult>` | Xcode 11 | 타깃별 `lineCoverage`, `coveredLines`, `executableLines` 추출 | |
| `actions/cache/restore`, `actions/cache/save` | v6.1.0 | CAS 보존 | 위의 SHA를 재사용한다 |
| composite action (`runs: using: composite`) | GitHub Actions | 공통 셋업 추출 | `uses: ./.github/actions/<이름>`은 체크아웃 **뒤에만** 쓸 수 있다 |

배포 타깃(iOS 17.0)과 관계없는 빌드 인프라 변경이라 런타임 폴백은 필요 없다.

### 알려진 함정
- **GHA 캐시 한도:** 저장소당 10 GB(초과분은 과금 설정이 있을 때만 허용), 7일 동안 안 쓰면 삭제, 넘치면 오래된 것부터
  지운다. CAS는 복원한 내용 위에 새 결과가 쌓이므로 저장할 때마다 커진다. 대응은 아래 결정 사항 "CAS 캐시 키" 참고.
- **캐시 범위:** PR(`refs/pull/N/merge`)은 자기 ref와 base 브랜치(`main`)의 캐시를 복원할 수 있다. `main`은 PR 캐시를
  못 본다. 그래서 `main`에서 저장해야 모든 PR이 혜택을 본다.
- **캐시 키에 Xcode 빌드 번호를 넣는다.** `xcode-27`은 preview 라벨이라 이미지가 바뀌면 Xcode 빌드가 바뀔 수 있다.
  `xcodebuild -version`의 마지막 줄(`Build version 27A…`)을 쓴다.
- **바이너리 캐시와 Release:** 로컬 CLI에서 `tuist generate`가 기본으로 `only-external` 바이너리 캐시 프로필을 쓰는 것을
  확인했다. 계정이 없어 캐시가 비어 있으니 지금은 소스 빌드다. 이번 범위에서 달라지는 것은 없다(Tuist 캐시를 도입할
  때 Release 잡에 `--cache-profile none`이 필요하다는 점만 README에 남긴다).
- **커버리지 계측 범위:** `-enableCodeCoverage YES`를 스킴의 `codeCoverageTargets` 없이 쓰면 외부 패키지(Firebase)까지
  계측해서 컴파일이 느려지고 표가 지저분해진다. 스킴에 대상 목록을 주었을 때 커맨드라인 플래그가 그 목록을 따르는지
  **구현 중 확인**(생성된 `.xcscheme`의 `onlyGenerateCoverageForSpecifiedTargets` 값과 xccov 보고서의 타깃 목록으로 확인).
- **커버리지와 CAS 키:** 커버리지 계측은 컴파일 입력을 바꾼다. 그래서 테스트 잡(커버리지 켬)과 Release 잡의 CAS를
  서로 다른 캐시 키로 나눈다.
- **job 이름 변경 금지:** README가 `build-test`를 required check로 걸라고 권장한다. 이름을 바꾸면 기존 설정이 PR을
  막는다. 새 잡 이름은 `release-build`로 정한다.

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 속도 접근 | 구조 개선(Release 병렬 잡) + A안(Xcode 컴파일 캐시 + `actions/cache`) | 계정 없이 가능한 범위. 사용자 선택. Tuist 서버 기능은 효과를 잰 뒤 후속 작업으로 |
| 직전 계획의 "DerivedData 캐시 범위 밖" 결정과의 충돌 | DerivedData 전체가 아니라 CAS만 캐시하고, 결정 게이트(1분 미만 단축이면 되돌림)를 둔다 | 직전 계획의 우려(불안정, 크기)를 CAS가 해소하는지 측정으로 판단한다 |
| 컴파일 캐시를 켜는 위치 | CI 워크플로에서 `xcbuild.sh`에 빌드 설정 인자로 넘김 | 로컬 동작과 `xcbuild.sh`를 바꾸지 않는다. 로컬 도입은 별도 판단 |
| CAS 캐시 저장 시점 | `github.event_name != 'pull_request'`(즉 `main` 푸시와 `workflow_dispatch`)이고 잡이 테스트/빌드 스텝까지 갔을 때(`!cancelled()`), CAS 디렉터리가 있을 때. `build-test`에서는 결과 업로드 스텝 **뒤**에 둔다 | PR마다 저장하면 한도가 금방 찬다. `workflow_dispatch`는 브랜치에서 효과를 미리 재기 위한 것. 업로드 뒤에 두는 이유는 테스트가 스텝 타임아웃으로 끊겼을 때 저장이 남은 잡 시간을 먹어 업로드가 취소되지 않게 하기 위해서다(리뷰 R1-2) |
| CAS 캐시 키 | `xcode-cas-<잡 종류>-<runner.os>-<runner.arch>-<Xcode 빌드>-<ISO 주(UTC, 예 2026-39)>-<hash(Package.resolved, Package.swift, mise.toml)>-<github.sha>`, restore-keys는 `<github.sha>`를 뺀 접두사 | 커밋마다 새 키로 저장해야 갱신된다(키가 같으면 저장이 건너뛰어진다). CAS는 복원한 내용 위에 쌓여 저장마다 커지므로, 의존성·Xcode가 오래 안 바뀌어도 주가 바뀌면 접두사가 달라져 새로 시작한다(리뷰 R1-1). 대가는 주마다 첫 `main` 푸시 한 번의 캐시 없는 빌드다. 그 전까지 PR은 두 번째 restore-key로 지난주 캐시를 복원한다(PR만. 저장하지 않으니 쌓이지 않는다. `main`에 주면 지난주 내용이 넘어와 다시 누적된다). 지난 주(ISO, UTC 월~일)에 `main` 푸시가 없었으면 이번 주 첫 `main` 푸시 전까지 PR도 캐시 없이 빌드한다(리뷰 R2-1). `COMPILATION_CACHE_LIMIT_SIZE`는 값 형식을 확인하지 못해 쓰지 않았다 |
| CAS 크기 상한 | 저장 전에 `du -sh`를 로그에 찍고, 1차 측정으로 판단한다. 저장 한 번에 3 GB를 넘으면 구현 중에 정리 방법을 정한다(`COMPILATION_CACHE_LIMIT_SIZE` 같은 설정이 있는지 확인. 없으면 저장을 건너뛰는 상한 검사) | 실제 크기를 모른다 |
| 공통 셋업 | `.github/actions/setup/action.yml` composite action | 두 잡 사이의 중복을 없앤다. 캐시 키와 순서가 한 곳에 모인다 |
| 커버리지 수집 | 스킴에 `coverage: false, codeCoverageTargets: [app] + modules`를 주고, CI 테스트 스텝에만 `-enableCodeCoverage YES` | 로컬 `xcbuild.sh test`는 느려지지 않는다. 표에는 앱과 모듈만 나온다 |
| 커버리지 보고 | `Scripts/coverage-summary.sh <xcresult>`가 마크다운 표를 stdout으로 내고, CI가 `$GITHUB_STEP_SUMMARY`에 붙인다 | 외부 서비스가 없다. 로컬에서도 같은 스크립트로 확인할 수 있다 |
| 커버리지 보고 스텝이 실패할 때 | 잡을 실패시킨다(`continue-on-error` 없음) | 조용히 빠지면 아무도 모른다. 스크립트가 xcresult가 없는 경우 등을 스스로 처리한다 |
| PR 템플릿 | `.github/pull_request_template.md` 하나(한국어) | 사용자 선택. 앱 이름을 하드코딩하지 않는다 |
| CODEOWNERS | 추가하지 않음. README에 "기여자가 둘 이상이 되고 모듈별 리뷰어가 생기면 추가" | 1인 저장소라 실효가 없다 |

## 변경 계획

각 단계는 브랜치에 푸시한 PR에서 CI가 초록이어야 끝난다. 작업 브랜치에서 진행한다(`main` 커밋은 훅이 막는다).

### 1. 공통 셋업을 composite action으로 추출
- 파일: `.github/actions/setup/action.yml`(신규), `.github/workflows/ci.yml`
- 변경:
  - `action.yml`에 `ci.yml:56-85`의 스텝을 그대로 옮긴다: mise 설치 → `xcodebuild -version` → SPM 캐시 복원 →
    `tuist install` → SPM 캐시 저장(`cache-hit != 'true'`) → `tuist generate --no-open`.
    composite의 `run` 스텝에는 `shell: bash`가 필수다. 복원 스텝의 `id`와 `steps.<id>.outputs` 참조는 composite 안에서도 쓴다.
  - 출력 `xcode-build`(예: `27A266a`)를 추가한다. `xcodebuild -version | awk '/Build version/ {print $3}'`를
    `$GITHUB_OUTPUT`에 쓴다. 3단계의 캐시 키가 쓴다.
  - 주석(캐시 복원/저장 분리 이유, mise 캐시 키 공유)도 함께 옮긴다.
  - `build-test`는 체크아웃 → `uses: ./.github/actions/setup` → 테스트 → Release 빌드 → 업로드 순서가 된다.
    이 단계에서 동작은 바뀌지 않는다.
- 검증: PR에서 `build-test`가 초록이다. 스텝 로그에 SPM 캐시 적중과 `tuist generate`가 composite 안에서 찍힌다.
  잡 시간이 기준(약 9분)과 비슷하다.

### 2. Release 빌드를 병렬 잡 `release-build`로 분리
- 파일: `.github/workflows/ci.yml`
- 변경:
  - `build-test`에서 "Release 빌드" 스텝을 뺀다. 테스트 뒤에 두었던 이유(xcresult를 먼저 확보)를 설명하던
    주석(`ci.yml:103-104`)은 지운다.
  - 새 잡 `release-build`: `runs-on`은 같은 식, `timeout-minutes: 30`, 체크아웃 → setup → `./.claude/scripts/xcbuild.sh build -configuration Release`.
  - 파일 상단 주석의 "lint 와 build-test 를 병렬로"를 세 잡으로 고친다.
  - 업로드 스텝의 주석 "(Release 빌드만 깨졌을 때는 …)"은 이제 해당하지 않으니 정리한다. 조건
    `failure() && steps.test.outcome == 'failure'`는 그대로 둔다.
- 검증: PR에서 세 잡이 병렬로 돌고 모두 초록이다. `build-test`가 약 7분, `release-build`가 약 3분(셋업 포함)으로
  줄어 run 전체가 약 7분이 된다. 실측을 기록한다.

### 3. Xcode 컴파일 캐시(CAS)와 캐시 보존
- 파일: `.github/workflows/ci.yml`(필요하면 `.github/actions/setup/action.yml`)
- 변경:
  - 두 잡의 xcodebuild 호출에 `COMPILATION_CACHE_ENABLE_CACHING=YES`를 붙인다(`xcbuild.sh`가 `"$@"`로 넘긴다).
  - 먼저 러너의 CAS 경로를 확인한다. 1회용 스텝에서 `xcodebuild -showBuildSettings … | grep COMPILATION_CACHE_CAS_PATH`로
    찍어 보고, 확인한 뒤 그 스텝은 지운다. 경로가 로컬과 같으면(`~/Library/Developer/Xcode/DerivedData/CompilationCache.noindex`)
    그대로 쓴다. 다르거나 불안정하면 `COMPILATION_CACHE_CAS_PATH="$RUNNER_TEMP/cas"`로 고정한다.
  - 빌드 스텝 앞에 `actions/cache/restore`(id `cas-cache`)를 둔다. 키는 결정 사항의 형식을 쓰고, 잡 종류는
    `test`(커버리지 계측 포함)와 `release`로 나눈다. Xcode 빌드 번호는 setup의 `xcode-build` 출력에서 읽는다.
  - 빌드 스텝 뒤에 `actions/cache/save`를 둔다. 조건은 `!cancelled() && github.event_name != 'pull_request'`.
    테스트가 실패해도 컴파일 결과는 유효하므로 저장한다. 저장 전에 `du -sh <CAS 경로>`를 찍는다.
  - 캐시 복원을 테스트 앞에 두었으므로 `ci.yml`의 "테스트 앞 스텝 합계 15분" 주석에 CAS 복원을 넣어 고치고,
    실측 복원 시간을 적는다.
  - 주석에 두 가지를 남긴다. PR에서 저장하지 않는 이유(10 GB 한도, `main` 캐시를 PR이 복원), 커밋 SHA로 키를 만드는
    이유(같은 키면 저장이 건너뛰어짐).
- 검증:
  1. 브랜치에서 `workflow_dispatch`를 두 번 돌린다. 첫 번째는 캐시 누락 후 저장, 두 번째는 복원한다.
  2. 두 번째 실행에 `COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES`를 임시로 켜서 Firebase 타깃의 컴파일 캐시 적중
     remark가 나오는지 확인한다. 확인한 뒤 끈다.
  3. 두 번째 실행의 `build-test`·`release-build` 시간, CAS 크기, 복원·저장 시간을 기록한다.
  4. **결정 게이트:** 두 번째 실행의 `build-test`가 2단계 측정보다 1분 이상 짧지 않으면 이 단계를 되돌리고
     README와 이 문서에 측정값과 "효과 없음"을 남긴다.

### 4. 커버리지 수집과 잡 요약 표시
- 파일: `Tuist/ProjectDescriptionHelpers/Scheme+Workspace.swift`, `Scripts/coverage-summary.sh`(신규, 실행 권한),
  `.github/workflows/ci.yml`
- 변경:
  - `Scheme+Workspace.swift`: `testAction`을
    `.targets(tests.map { .testableTarget(target: $0) }, options: .options(coverage: false, codeCoverageTargets: [app] + modules))`로
    바꾼다. 문서 주석 표에 "커버리지 대상: 앱과 모듈 구현 타깃. 수집은 CI가 `-enableCodeCoverage YES`로 켠다"를 한 줄 추가한다.
    정확한 시그니처(인자 이름과 순서)는 Tuist 4.208.0의 `TestAction.targets`를 **구현 중 확인**한다.
  - `Scripts/coverage-summary.sh`:
    - `set -euo pipefail`. 인자로 xcresult 경로를 받고, 없거나 디렉터리가 아니면 사용법을 stderr로 내고 exit 1.
    - `xcrun xccov view --report --json "$1"`을 `jq`로 가공해 마크다운을 낸다. 제목 `### 코드 커버리지`,
      전체 라인 커버리지, 타깃별 행(`| 타깃 | 라인 커버리지 | 커버/전체 |`). 커버리지 오름차순으로 정렬한다.
    - 테스트 번들(`.xctest`)은 방어적으로 한 번 더 걸러낸다. 이름(`*Tests`)으로는 거르지 않는다. 이름이 `Tests`로
      끝나는 구현 모듈이 표에서 조용히 빠지기 때문이다(리뷰 R1-5).
    - 보고서에 타깃이 없으면(커버리지를 안 켜고 돌린 번들) "커버리지 데이터가 없습니다" 한 줄을 내고 exit 0.
    - 앱 이름이나 모듈 이름을 하드코딩하지 않는다.
  - `ci.yml`의 테스트 스텝에 `-enableCodeCoverage YES`를 추가한다.
  - 테스트 스텝 뒤에 "커버리지 요약" 스텝을 둔다(`if: steps.test.outcome == 'success'`,
    `Scripts/coverage-summary.sh "$RUNNER_TEMP/TestResults.xcresult" >> "$GITHUB_STEP_SUMMARY"`).
  - 커버리지 계측은 컴파일 입력을 바꾼다. 3단계를 유지했다면 `test` CAS 키의 접두사에 `cov`를 넣어 기존 캐시와 섞이지 않게 한다.
- 검증:
  - 로컬: `tuist generate --no-open` 후 `./.claude/scripts/xcbuild.sh test -resultBundlePath <scratch>/R.xcresult -enableCodeCoverage YES`,
    그다음 `Scripts/coverage-summary.sh <scratch>/R.xcresult`를 실행한다. 표에 앱과 모듈 8개만 나오고
    Firebase, `*Tests`, `*Demo`가 없어야 한다.
  - 로컬: 커버리지 없이 만든 번들로 스크립트를 돌리면 "데이터 없음" 메시지가 나오고 exit 0이다. 인자 없이 돌리면 exit 1이다.
  - 생성된 `TuistApp-Workspace.xcscheme`에 `codeCoverageEnabled = "NO"`와 대상 목록이 들어간다.
  - CI: 잡 요약 페이지에 표가 뜬다. 테스트 스텝 시간 증가분을 기록한다.
  - `mise exec -- swiftformat --lint .`와 `mise exec -- swiftlint lint --quiet`를 통과한다.

### 5. PR 템플릿
- 파일: `.github/pull_request_template.md`(신규)
- 변경: 섹션은 `## 요약`, `## 변경 사항`, `## 테스트`(실행한 명령과 결과), `## 스크린샷`(UI 변경 시. 없으면 지움),
  `## 체크리스트`. 체크리스트 항목은 다음과 같다.
  - `./.claude/scripts/xcbuild.sh test` 통과
  - 스냅샷 기준 이미지를 갱신했다면 이유를 적음
  - 계획 문서(`docs/plans/…`)가 있다면 링크
  - 생성 파일 직접 편집 없음

  주석(`<!-- -->`)으로 각 섹션 안내를 짧게 단다. 앱 이름은 쓰지 않는다.
- 검증: 브랜치 PR을 만들 때 본문이 템플릿으로 채워진다. 기본 브랜치에 머지된 뒤 새 PR부터 적용되므로 머지 후 확인한다.

### 6. README 갱신
- 파일: `README.md`(`## CI` 절, `## 새 앱으로 복제할 때 바꿀 곳`)
- 변경:
  - 소개 문장을 "세 잡을 병렬로"로 고친다. 잡 표에 `release-build` 행을 추가하고, `build-test` 행에서 Release를 빼고 커버리지를 넣는다.
  - 새 불릿:
    - **컴파일 캐시**: CI에서만 켠다. `main` 푸시 때 저장하고 PR은 복원만 한다. 측정값을 적는다.
      캐시가 의심스러우면 Actions > Caches에서 `xcode-cas-` 항목을 지운다.
    - **커버리지**: 잡 요약에 표가 뜬다. 로컬 재현 명령(4단계 검증 명령)을 적는다. 게이트는 없다.
    - **Tuist 캐시·선택적 테스트**: 계정이 필요해서 도입하지 않았다. 도입하면 Release 잡에 `--cache-profile none`이 필요하다.
  - 브랜치 보호 권장 목록에 `release-build`를 추가하고, 기존 설정에도 새 잡을 required로 추가하라고 적는다.
  - "CODEOWNERS는 기여자가 둘 이상이 되고 모듈별 리뷰어가 생기면 추가한다" 한 줄을 넣는다.
  - `## 새 앱으로 복제할 때 바꿀 곳`에 `.github/actions/setup`과 PR 템플릿은 바꿀 곳이 없다는 것을 명시한다.
- 검증: README의 명령을 그대로 복사해 로컬에서 돌아간다. 잡 이름이 `ci.yml`과 일치한다.

## 테스트 전략

- Swift 테스트는 추가하지 않는다. 앱 동작이 바뀌지 않고, 스킴 변경은 생성 결과(`.xcscheme`)와 CI 실행으로 검증한다.
- `Scripts/coverage-summary.sh`는 셸 테스트 프레임워크가 없으니 4단계 검증의 세 경우(정상 번들, 커버리지 없는 번들,
  인자 없음)를 로컬에서 직접 돌려 확인한다.
- 워크플로 변경은 브랜치 PR과 `workflow_dispatch` 실행으로 검증한다. 각 단계의 실측(잡 시간, 캐시 크기)을 이 문서의
  "측정 기록" 절(구현 중 추가)에 남긴다.
- 기존 테스트는 수정하지 않는다. 스냅샷 테스트가 커버리지 계측 때문에 달라지지 않는지 CI에서 확인한다
  (계측은 렌더링에 영향이 없어야 한다).

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| 컴파일 캐시가 Firebase(Tuist가 통합한 SPM 타깃)에 적중하지 않아 효과가 미미하다 | 중 | 3단계 진단 remark로 확인하고 결정 게이트로 되돌린다. Tuist 바이너리 캐시 후속 작업의 근거로 삼는다 |
| CAS 크기가 커서 복원·저장이 단축분을 까먹거나 10 GB 한도를 압박한다 | 중 | 3단계에서 크기와 복원 시간을 측정한다. 상한 검사를 넣거나 게이트로 되돌린다 |
| 캐시가 오염되어(다른 Xcode 빌드 등) 이상한 빌드 실패가 난다 | 낮 | 키에 Xcode 빌드 번호와 의존성 해시를 넣는다. README에 캐시 삭제 방법을 적는다 |
| macOS 동시 실행 한도 때문에 세 잡 중 일부가 대기한다(PR과 main 푸시가 겹칠 때) | 낮 | run 하나당 macOS 잡이 3개가 된다(lint도 macOS 러너). 무료 플랜의 macOS 동시 실행 한도와 비교해 대기가 관찰되면 기록한다 |
| `-enableCodeCoverage YES`가 스킴의 대상 목록을 무시하고 Firebase까지 계측한다 | 중 | 4단계 검증에서 xccov 타깃 목록으로 확인한다. 무시하면 스킴 `coverage: true`로 바꾸는 방안(로컬도 수집)을 사용자에게 묻는다 |
| 커버리지 계측으로 테스트 스텝이 크게 느려진다 | 중 | 증가분을 측정한다. 1분이 넘으면 `main` 푸시에서만 커버리지를 켜는 방안을 사용자에게 묻는다 |
| required check에 `release-build`가 빠져 Release 전용 컴파일 에러가 있는 PR이 머지된다 | 중 | README에 required check 갱신을 명시하고, 완료 보고에서 사용자에게 설정 변경을 안내한다 |
| composite action 안에서 `mise`가 설치한 도구가 뒤 스텝의 PATH에 안 잡힌다 | 낮 | mise-action은 `GITHUB_PATH`로 올리므로 composite 밖의 스텝에도 유효하다. 1단계 검증에서 확인한다 |

## 측정 기록

### 로컬 (2026-09-23, Xcode 27, Apple Silicon)
- Xcode 27에 `COMPILATION_CACHE_LIMIT_SIZE` 설정이 있다(기본 0). CAS 크기 상한이 필요해지면 이것부터 검토한다.
- Release 빌드 1회 뒤 CAS 크기: 999 MB(3 GB 상한 아래).
- 커버리지: `-enableCodeCoverage YES`는 스킴의 `codeCoverageTargets`를 따른다. xccov 보고서의 타깃은 앱과 모듈
  8개(TuistApp, Data, DesignSystem, Diagnostics, Domain, Home, Navigation, Networking)뿐이고 Firebase, `*Tests`,
  `*Demo`는 없다. 생성된 스킴은 `onlyGenerateCoverageForSpecifiedTargets = "YES"`이고 `codeCoverageEnabled`
  속성은 생략된다(기본값 NO).
- `coverage-summary.sh`: 정상 번들이면 표(전체 40.0%), 커버리지 없는 번들이면 "데이터 없음"과 exit 0,
  인자 없음·경로 없음·깨진 번들이면 exit 1.

### CI (2026-09-23, 러너 `xcode-27`, Xcode `27A266a`, macOS ARM64)
구현은 단계별로 푸시하지 않고 PR에서 한 번에 검증했다(사용자 결정). 세 실행 모두 같은 커밋 `5329948`이다.

| 실행 | 컴파일 캐시 | `build-test` 잡 | 테스트 스텝 | `release-build` 잡 | Release 빌드 스텝 | 셋업 |
|---|---|---|---|---|---|---|
| PR 35839064910 | 없음(PR은 저장 안 함) | 7분 30초 | 6분 15초 | 2분 44초 | 1분 45초 | 약 55초 |
| dispatch 35840070810 | 없음 → 저장 | 6분 36초 | 5분 15초 | 3분 16초 | 1분 57초 | 약 1분 |
| dispatch 35840858706 | 복원(두 잡 모두 정확 적중) | 9분 59초 | 8분 01초 | 5분 13초 | 3분 31초 | 약 1분 30초 |

- 2단계(Release 병렬화): 기준 `build-test` 약 9분 08초가 6분 36초~7분 30초로 줄었다. run 전체(크리티컬 패스)는 약 7분 40초.
  `release-build`(약 3분)는 `build-test`보다 먼저 끝나 크리티컬 패스에 들지 않는다.
- 4단계(커버리지): 테스트 스텝이 기준 6분 06초 대비 +9초(같은 기간 `main`에 모듈 2개가 추가된 것을 포함). 1분 기준보다 작아 유지.
- 3단계(컴파일 캐시):
  - CAS 크기는 `build-test` 699 MB(캐시 압축 252 MB), `release-build` 1.1 GB(448 MB). 저장 6초·9초, 복원 10초·13초.
  - **결정 게이트 불통과.** 캐시를 복원한 실행의 `build-test`가 캐시 없는 실행보다 3분 23초 느렸다(기준은 캐시 없는
    두 실행 중 짧은 6분 36초). `release-build`도 1분 57초 느렸다. 캐시와 무관한 셋업도 28초 느려 러너 편차가 섞였지만,
    단축된 곳이 없어 게이트(1분 이상 단축)를 만족할 여지가 없다.
  - 원인은 확인하지 않았다(진단 remark를 켜지 않음). 캐시 적중에도 컴파일을 건너뛰지 못했거나, CAS 조회·적재 비용이
    이득보다 컸을 수 있다. 다시 시도한다면 `COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES`로 적중 여부부터 본다.
  - 조치: 3단계 커밋 `8932bec`를 되돌리고, 4단계가 바꾼 `test-cov` 키와 캐시용으로만 쓰던 setup 출력(`xcode-build`,
    `cache-week`, `cache-prev-week`)을 함께 정리했다. 저장된 `xcode-cas-` 캐시 두 개는 지웠다.
  - Tuist 바이너리 캐시(범위 밖)는 이 결과와 별개로, 계정이 생기면 따로 판단한다.

## 롤백

- 단계마다 커밋이 하나라 `git revert <커밋>`으로 개별 롤백할 수 있다. 3단계(컴파일 캐시)는 다른 단계와 독립이라
  결정 게이트에 걸리면 그 커밋만 되돌린다. 4단계가 3단계 뒤에 CAS 키 접두사를 바꿨다면 그 줄만 같이 정리한다.
- CAS 캐시 항목은 Actions > Caches에서 `xcode-cas-` 접두사로 지우거나 `gh cache delete --all`(해당 키)로 지운다.
  남겨 둬도 7일 뒤 자동으로 삭제된다.
- `release-build`를 되돌리면 브랜치 보호의 required check에서도 빼야 PR이 막히지 않는다.
