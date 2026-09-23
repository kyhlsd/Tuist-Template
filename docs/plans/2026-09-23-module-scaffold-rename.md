# 모듈 스캐폴딩과 앱 이름 변경 스크립트

## 목표

- `Scripts/new-module.sh feature Profile --demo`를 한 번 실행하면 `tuist generate`와 `./.claude/scripts/xcbuild.sh build`/`test`가 추가 수정 없이 통과한다.
  폴더 생성, `Project.swift` 작성, `Module.all`/`Module.withDemoApp` 등록을 모두 스크립트가 한다.
- `Scripts/new-module.sh core Analytics --testing`도 같다. 새 Core 모듈은 `Module.swift`에 case를 추가하지 않고 목록에 `.core("Analytics")` 한 줄만 더해 등록된다.
- `Scripts/rename.sh <NewName> <bundlePrefix> [<organizationName>]`을 깨끗한 작업 트리에서 실행하면
  - `tuist install && tuist generate`와 `xcbuild.sh build`/`test`가 통과한다.
  - `git grep -I -e <옛 앱 이름> -e <옛 URL 스킴>`(대소문자 구분, `docs/plans/` 제외)의 결과가 0줄이다.
- README의 "모듈 추가"와 "새 앱으로 복제할 때 바꿀 곳"이 두 스크립트 사용법으로 바뀐다.

## 범위 밖

- 기존 Core 모듈(`.domain`, `.data` 등)을 `.core(String)`으로 옮기는 작업. 이름 있는 case를 그대로 둔다.
- `App/Project.swift`에 새 피처 의존성을 자동으로 추가하는 것. 스크립트는 다음 할 일을 안내만 한다.
- 스캐폴드 결과를 CI에서 검증하는 잡. 템플릿이 코드베이스 변경을 따라가지 못하는 위험은 위험 요소에 적는다.
- rename 스크립트가 처리하지 않는 외부 설정. 대상은 Firebase `GoogleService-Info.plist`, `ClientKeys.xcconfig`, App Store Connect 번들 ID 등록, 저장소 폴더 이름이다. README에 수작업 항목으로 남긴다.
- `docs/plans/`의 과거 계획 문서. 당시 기록이므로 치환하지 않는다.

## 전제

### 버전과 도구
- Tuist 4.208.0(`mise.toml`), iOS 17.0, Swift 6.0.
- 두 스크립트 모두 빌드 도구 영역이다. iOS API 가용성이나 폴백과는 관계가 없다.
- 새 외부 의존성은 없다. macOS 기본 bash 3.2, `perl`, `git`, `mise exec -- tuist`만 쓴다.

### 현재 모듈 등록 구조 (`Tuist/ProjectDescriptionHelpers/Module.swift`)
- `enum Module`은 `.feature(String)`, `.featureInterface(String)`과 이름 있는 Core case 6개(`.domain`, `.data`, `.designSystem`, `.networking`, `.navigation`, `.diagnostics`)로 이뤄진다(44-63행).
- `name`(65행~)과 `path`(83-90행)의 switch가 case마다 갈린다. `path`는 Core가 `Modules/Core/<name>`, 피처가 `Modules/Features/<name>`이다.
- `Module.all`(115-123행)과 `Module.withDemoApp`(129-132행)이 등록부다.
- `validateRegistration(name:hasDemoApp:)`(137-148행)은 `Project.core`/`Project.feature`가 호출한다. 등록부와 매니페스트가 어긋나면 `fatalError`로 generate를 멈춘다. 스크립트가 등록을 빠뜨리면 여기서 바로 드러난다.
- `Scheme+Workspace.swift`는 `Module.all`과 `withDemoApp`으로 워크스페이스 스킴의 빌드·테스트 대상을 만든다. 등록만 하면 스킴에 자동으로 들어간다.

### 템플릿이 재현해야 할 모듈 구조 (`Project+Templates.swift`)
- `Project.feature(name:interfaceDependencies:dependencies:testDependencies:hasResources:hasTestingSupport:testingDependencies:hasDemoApp:demoDependencies:hasSnapshotTests:)`
- `Project.core(name:dependencies:testDependencies:hasResources:hasTestingSupport:testingDependencies:hasDemoApp:demoDependencies:isMainActorByDefault:hasSnapshotTests:)`
- 폴더 규칙은 다음과 같다. `Sources/`와 `Tests/`는 항상 있다. `Interface/Sources/`는 feature에만, `Resources/`는 `hasResources`일 때, `Testing/Sources/`는 `hasTestingSupport`일 때, `Demo/Sources/`(`@main`)는 `hasDemoApp`일 때 있다.
- `enforceExplicitDependencies`가 켜져 있다. 생성하는 소스가 import하는 모듈은 해당 `*Dependencies`에 모두 적어야 한다. 템플릿이 자동으로 넣는 것은 같은 프로젝트 안의 타깃뿐이다.
- 참고 구현은 `Modules/Features/Home/Project.swift`, `Modules/Features/Home/Interface/Sources/HomeRoute.swift`(`public enum HomeRoute: Route`), `Modules/Features/Home/Demo/Sources/HomeDemoApp.swift`(`Router` + `NavigationStack` + `.theme(.standard)`), `Modules/Core/Domain/Project.swift`다.
- `Route`는 `public nonisolated protocol Route: Hashable, Sendable {}`이다(`Modules/Core/Navigation/Sources/Route.swift`).

### Tuist scaffold (4.208.0 태그 소스로 확인)
- 위치는 `Tuist/Templates/<name>/<name>.swift`다. `Template(description:attributes:items:)`로 선언한다.
- `Attribute.required("name")`와 `.optional("demo", default: .string("false"))`로 CLI 옵션을 받는다.
- `Item.file(path:templatePath:)`는 `.stencil` 확장자일 때만 렌더링한다. 다른 확장자는 그대로 복사한다. `Item.string(path:contents:)`도 있다.
- item의 `path`는 항상 Stencil로 렌더링된다. `"Modules/Features/{{ name }}/Project.swift"`처럼 쓸 수 있다.
- 실행 형식은 `tuist scaffold <template> --name X --demo true -p <출력 기준 경로>`다.
- **함정**
  1. 렌더 결과가 공백뿐인 파일은 생성되지 않는다. 예외는 `.gitkeep`이다.
  2. 이미 있는 경로를 조용히 덮어쓴다. `nonEmptyDirectory` 에러는 정의만 돼 있고 던지지 않는다.
  3. CLI로 넘긴 optional 값은 전부 `.string`이다. `{% if demo %}`는 `"false"`여도 참으로 평가된다. 반드시 `{% if demo == "true" %}`로 비교한다.
  4. 조건부 파일 생성은 지원하지 않는다(tuist/tuist#6862).
  5. 기존 파일을 부분 수정할 수 없다. `Module.swift` 등록은 스크립트가 한다.

### 앱 이름 하드코딩 위치 (2026-09-23 grep 결과, `docs/plans/` 제외)
| 문자열 | 위치 |
|---|---|
| `TuistApp` (값) | `AppConstants.swift:20` `appName`, `Tuist/Package.swift:13` `name:`, `.claude/scripts/xcbuild.sh:21,23,26`, `App/Tests/*.swift`의 `@testable import TuistApp` 10개 파일, `Modules/Core/Networking/OpenAPI/openapi.yaml:6` `title`(생성물에는 나오지 않으므로 `--check`에 영향이 없다) |
| `TuistApp` (파일명·타입명) | `App/Sources/TuistAppApp.swift`(`struct TuistAppApp`), `App/Tests/TuistAppTests.swift`(`struct TuistAppTests`) |
| `TuistApp` (문서) | `README.md:1,13,24,89,90,159,180,181`, `CLAUDE.md:8`, `.claude/README.md:327`, `Modules/Core/Navigation/README.md:284,294` |
| `TuistApp` (헤더 주석) | 파일 31개의 `//  TuistApp`, `//  TuistAppTests`, `//  TuistAppManifests`, `//  _TuistAppManifests` |
| `tuistapp` | `AppConstants.swift:25,29` `urlScheme`, `App/Tests/{PushPayload,DeepLinkParser,AppRouter}Tests.swift`의 URL 리터럴, `App/Sources/Navigation/DeepLinkParser.swift:11` 주석, `Modules/Core/Navigation/README.md`, `Modules/Core/Diagnostics/README.md:174`(`com.olivebridge.tuistapp`) |
| `com.olivebridge` | `AppConstants.swift:21`, `Modules/Core/Navigation/README.md:305`, `Modules/Core/Diagnostics/README.md:174` |
| `Olive Bridge` | `AppConstants.swift:22` |

- `TuistApp.xcworkspace`와 `Configurations/ClientKeys.xcconfig`는 gitignore 대상이다. rename의 치환 대상이 아니다.
- 앱 테스트의 URL은 스킴을 가리지 않고 파싱한다(`DeepLinkParser` 주석). `tuistapp` 리터럴을 바꿔도 테스트 결과는 같다. 일관성을 위해 치환한다.

### 스크립트 스타일 (선례: `Scripts/openapi-generate.sh`, `.claude/scripts/xcbuild.sh`)
- `#!/usr/bin/env bash`로 시작하고, 상단 주석에 사용법을 적고, `set -euo pipefail`을 건다.
- 루트는 `root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`로 고정한다.
- 오류는 `die() { printf '%s\n' "$*" >&2; exit 1; }`로 처리한다.
- 임시 파일은 `mktemp -d`와 `trap`으로 정리한다. 도구는 `mise exec --`로 호출한다.
- bash 3.2라서 `${v,,}`와 연관 배열을 쓸 수 없다. 소문자 변환은 `tr '[:upper:]' '[:lower:]'`로 한다.
- 파일 내 치환은 BSD/GNU 차이가 없는 `perl -pi -e`를 쓴다.

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 스캐폴딩 방식 | `tuist scaffold` 템플릿 + 래퍼 `Scripts/new-module.sh` | scaffold는 기존 파일을 수정하지 못한다. 등록과 존재 검사는 래퍼가 맡는다. 템플릿은 `.stencil`로 두어 읽고 고치기 쉽다(사용자 선택) |
| 새 Core 모듈 등록 | `Module`에 `case core(String)`를 추가한다. 기존 이름 있는 case는 유지한다 | 새 Core 모듈을 목록 한 줄로 등록할 수 있다. 그러지 않으면 enum case와 switch 두 곳을 perl로 고쳐야 한다(사용자 선택) |
| 등록부 삽입 위치 | `Module.all`과 `withDemoApp` 배열의 닫는 `]` 바로 앞에 마커 주석을 두고, 그 줄 위에 삽입한다 | 배열 구조를 정규식으로 추측하지 않는다. 마커가 없으면 스크립트가 멈춘다 |
| 옵션 모듈(Demo/Testing/Resources) | 템플릿은 feature와 core 두 개다. 모든 폴더를 만들고, 래퍼가 요청하지 않은 폴더를 지운다. `Project.stencil`은 `{% if demo == "true" %}`로 플래그를 반영한다 | 조건부 파일 생성이 없다(#6862). 추가 템플릿 5개보다 단순하다. 지우는 대상은 방금 만든 새 폴더뿐이라 안전하다 |
| scaffold 출력 경로 | `-p "$root"`와 루트 기준 item 경로(`Modules/Features/{{ name }}/...`) | cwd에 따라 결과가 달라지지 않는다 |
| 덮어쓰기 방지 | 래퍼가 `Modules/Core/<Name>`과 `Modules/Features/<Name>` 중 하나라도 있으면 중단한다. `Module.swift`에 `"<Name>"`이 이미 있어도 중단한다 | scaffold가 조용히 덮어쓴다 |
| 모듈 이름 검증 | `^[A-Z][A-Za-z0-9]*$` | 타깃 이름과 Swift 모듈 이름으로 쓰인다. 기존 모듈처럼 UpperCamel이다 |
| 실패 시 복구 | 래퍼가 시작 전에 `Module.swift`를 백업한다. 실패하면 `trap`이 새 폴더를 지우고 백업을 복원한다 | 반쯤 만들어진 상태로 남지 않게 한다 |
| 생성할 기본 의존성 | feature는 Interface → Navigation, 구현 → DesignSystem·Navigation, Demo → DesignSystem·Navigation이다. core는 의존성 없음 | 생성하는 샘플 소스가 import하는 것만 적는다(enforceExplicitDependencies) |
| rename 입력 | `<NewName> <bundlePrefix> [<organizationName>]`. 옛 값은 `AppConstants.swift`에서 읽는다 | 하드코딩이 없어 다시 실행할 수 있다(A→B→C). organizationName을 생략하면 바꾸지 않는다 |
| rename 검증 | 앱 이름은 `^[A-Za-z][A-Za-z0-9]*$`, 번들 접두사는 `^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*$`로 검증한다. 작업 트리가 깨끗해야 실행한다 | 앱 이름은 `@testable import`(Swift 식별자), 번들 ID(CFBundleIdentifier), URL 스킴(RFC 3986)에 모두 쓰이므로 셋의 교집합으로 좁힌다(리뷰 R1-1). 되돌리기는 `git checkout`/`git clean`에 맡긴다 |
| rename 치환 범위 | `git ls-files` 중 텍스트 파일 전부. 제외는 `docs/plans/`, `*.generated.swift`, 바이너리다. 치환 규칙은 `<옛 이름>` → `<새 이름>`, `<옛 스킴>` → `<새 이름 소문자>`, `<옛 접두사>` → `<새 접두사>`, (주면) `<옛 조직>` → `<새 조직>`. 대소문자를 구분하는 부분 문자열 치환이다 | 사용자 선택(헤더 주석 포함 전부). `TuistAppApp`, `TuistAppTests`, `TuistAppManifests`는 부분 문자열 치환으로 함께 바뀐다 |
| 파일명 변경 | `git ls-files`에서 경로에 옛 이름이 들어간 파일을 `git mv`한다 | 대상은 `TuistAppApp.swift`, `TuistAppTests.swift`다. "타입당 한 파일, 파일명 = 타입명" 규칙을 지킨다 |
| URL 스킴 | 새 앱 이름을 소문자로 바꾼 값 | 현재 규칙(`TuistApp` → `tuistapp`)을 따른다 |

## 변경 계획

작업 브랜치를 먼저 만든다(`main` 직접 커밋은 훅이 막는다). 예: `feat/module-scaffold-rename`.

### 1. `Module.core(String)`과 등록부 마커
- 파일: `Tuist/ProjectDescriptionHelpers/Module.swift`
- 변경:
  - `// MARK: Core`에 `case core(String)`을 추가한다. 문서 주석에는 "새 Core 모듈은 이 case로 추가한다. 기존 모듈은 이름 있는 case를 유지한다"를 적는다.
  - `name`: `case let .core(name): name`
  - `path`: `.core`를 `Modules/Core/\(name)` 분기에 합친다.
  - `Module.all`과 `withDemoApp` 배열의 닫는 `]` 바로 앞 줄에 마커 주석을 둔다. 문구는 구현 중 확정한다. 예: `// new-module.sh 가 이 줄 위에 추가한다.`
  - 상단 의존 방향 다이어그램 주석은 필요하면 한 줄 보탠다.
- 검증: `mise exec -- tuist generate --no-open`, `./.claude/scripts/xcbuild.sh build` 통과. 동작 변화는 없다.

### 2. scaffold 템플릿 (feature, core)
- 파일:
  - `Tuist/Templates/feature/feature.swift`, `Tuist/Templates/feature/*.stencil`
  - `Tuist/Templates/core/core.swift`, `Tuist/Templates/core/*.stencil`
- 변경:
  - 속성은 `name`(required), `demo`, `testing`, `resources`(optional, 기본값 `"false"`)다.
  - feature item(경로 접두사 `Modules/Features/{{ name }}/`):
    - `Project.swift`: `Project.feature(...)`. `hasResources`, `hasTestingSupport`, `hasDemoApp`과 그에 딸린 `demoDependencies`/`testDependencies`를 `{% if x == "true" %}`로 채운다.
    - `Interface/Sources/{{ name }}Route.swift`: `public enum {{ name }}Route: Route`. case 구성은 구현 중 확인한다. 빈 enum의 Hashable 합성 여부를 보고, 안 되면 case 하나를 둔다.
    - `Sources/{{ name }}View.swift`: `public struct {{ name }}View: View`와 `public init()`
    - `Tests/{{ name }}Tests.swift`: Swift Testing `@Suite`와 최소 테스트 1개(예: Route 동등성)
    - `Testing/Sources/{{ name }}Testing.swift`: Interface를 import하는 최소 타입
    - `Demo/Sources/{{ name }}DemoApp.swift`: `HomeDemoApp` 형태(`Router`, `NavigationStack`, `.theme(.standard)`)
    - `Resources/Localizable.xcstrings`: 빈 문자열 카탈로그. `sourceLanguage`는 Home의 `Localizable.xcstrings`와 맞춘다(구현 중 확인).
  - core item(경로 접두사 `Modules/Core/{{ name }}/`): `Project.swift`(`Project.core(...)`), `Sources/`, `Tests/`, `Testing/Sources/`, `Demo/Sources/`, `Resources/`를 feature와 같은 방식으로 만든다. Interface는 없다.
  - 생성되는 Swift 소스의 제약:
    - `.claude/rules/swift.md`를 지킨다. 문자열 리터럴 UI 텍스트, 강제 언래핑, 싱글턴을 쓰지 않는다.
    - 렌더 결과가 SwiftFormat과 SwiftLint를 통과해야 한다.
    - 헤더 주석은 기존 파일처럼 `//  {{ name }}View.swift` / `//  {{ name }}` 형식으로 둔다(작성자 줄 없음).
  - 매니페스트(`feature.swift`, `core.swift`)도 `.swift`라 lint와 format 대상이다. 통과해야 한다.
- 검증: 이 단계만으로는 등록이 없어 generate가 `fatalError`로 멈춘다. 이것이 의도대로라는 것만 확인한다. 임시로 `mise exec -- tuist scaffold feature --name Tmp --demo true -p .`를 실행하고 파일 목록과 렌더 결과를 확인한 뒤 지운다. 커밋 전 `swiftformat --lint .`와 `swiftlint lint --quiet`가 통과해야 한다.

### 3. `Scripts/new-module.sh`
- 파일: `Scripts/new-module.sh`(실행 권한)
- 사용법: `Scripts/new-module.sh <feature|core> <Name> [--demo] [--testing] [--resources]`
- 흐름:
  1. 인자와 이름을 검증한다. 두 폴더 중 하나라도 있거나 `Module.swift`에 `"<Name>"`이 있으면 중단한다. 마커 두 개가 없어도 중단한다.
  2. `Module.swift`를 임시 디렉터리에 백업하고 `trap`을 건다. 실패하면 새 모듈 폴더를 지우고 백업을 복원한다.
  3. `mise exec -- tuist scaffold <kind> --name <Name> --demo <true|false> --testing <…> --resources <…> -p "$root"`를 실행한다. 출력은 로그 파일로 보내고 실패할 때만 보여 준다(openapi-generate.sh와 같은 방식).
  4. 플래그가 꺼진 옵션 폴더(`Demo`, `Testing`, `Resources`)를 새 모듈 폴더 안에서만 지운다.
  5. perl로 `Module.all` 마커 위에 `.feature("<Name>"),` 또는 `.core("<Name>"),`를 삽입한다. `--demo`면 `withDemoApp`에도 삽입한다. 들여쓰기는 마커 줄의 것을 따른다.
  6. 삽입 후 해당 줄이 정확히 한 번씩 있는지 확인한다.
  7. 다음 할 일을 출력한다. feature면 `App/Project.swift`에 `.module(.feature("<Name>"))`와 `.module(.featureInterface("<Name>"))`를 추가하라고 안내하고, `tuist generate` 실행을 안내한다.
- 검증:
  - `Scripts/new-module.sh feature Sample --demo --testing --resources` → `tuist generate --no-open` → `xcbuild.sh build` → `xcbuild.sh test` 모두 통과. 워크스페이스 스킴에 `SampleTests`와 `SampleDemo`가 포함된다.
  - `Scripts/new-module.sh core SampleCore` (플래그 없음) → 같은 검증. `Testing/`, `Demo/`, `Resources/` 폴더가 없어야 한다.
  - 같은 이름으로 다시 실행하면 파일 변경 없이 exit 1. 잘못된 이름(`sample`, `1Foo`)도 exit 1.
  - 확인 후 `git checkout Tuist/ProjectDescriptionHelpers/Module.swift`와 `git clean`으로 샘플 모듈을 지운다. 샘플은 커밋하지 않는다.

### 4. README "모듈 추가" 갱신
- 파일: `README.md`(134-153행)
- 변경: 첫 줄에 `Scripts/new-module.sh` 사용법과 옵션 표를 둔다. 기존 수작업 단계는 "스크립트가 하는 일"로 줄인다(폴더 표는 유지). `App/Project.swift` 연결은 수동이라고 적는다. 새 Core 모듈은 `.core("Name")`으로 참조한다고 적는다.
- 검증: 문서만 바뀐다. 기술한 명령이 3단계에서 실행한 것과 같아야 한다.

### 5. `Scripts/rename.sh`
- 파일: `Scripts/rename.sh`(실행 권한)
- 사용법: `Scripts/rename.sh <NewName> <bundlePrefix> [<organizationName>]`
- 흐름:
  1. 인자를 검증한다(결정 사항의 정규식). `git status --porcelain`이 비어 있지 않으면 중단한다.
  2. `AppConstants.swift`에서 `appName`, `bundleIDPrefix`, `organizationName`, `urlScheme`의 현재 값을 perl로 읽는다. 하나라도 읽지 못하면 중단한다. 새 값이 옛 값과 모두 같으면 아무것도 하지 않고 끝낸다.
  3. `git ls-files -z`에서 `docs/plans/`와 `*.generated.swift`를 빼고 텍스트 파일(`grep -Iq .`)만 고른다.
  4. perl로 치환한다. 순서는 조직 → 번들 접두사 → 앱 이름 → 스킴이다. 옛 이름이 새 이름의 부분 문자열인 경우(예: `App` → `MyApp`)도 한 번만 치환되도록 한 파일당 perl 한 번에 모두 처리한다(`\Q…\E` 사용).
  5. 경로에 옛 이름이 들어간 추적 파일을 `git mv`한다.
  6. 다음을 확인한다. 치환 후 옛 이름과 옛 스킴의 `git grep -I` 결과가 0줄인지 확인하고, 아니면 목록을 출력하고 exit 1한다. 출력은 바뀐 파일 수와 다음 할 일(`tuist install && tuist generate`, 옛 `*.xcworkspace` 삭제, 외부 설정 목록)이다.
- 검증(본 저장소를 건드리지 않도록 스크래치의 `git worktree`에서 한다):
  - `Scripts/rename.sh Sample com.example "Example Inc"` → `mise exec -- tuist install && mise exec -- tuist generate --no-open` → 워크트리의 `xcbuild.sh build`와 `test` 통과.
  - `git grep -I -e TuistApp -e tuistapp -e olivebridge -- ':!docs/plans'` 결과가 0줄이다.
  - `App/Sources/SampleApp.swift`의 `struct SampleApp`과 `App/Tests/SampleTests.swift`를 확인한다.
  - 같은 워크트리에서 `Scripts/rename.sh Other com.other`를 한 번 더 실행해도 통과한다(재실행성).
  - 잘못된 입력(`1App`, `com..x`)과 더러운 작업 트리는 exit 1이고 파일이 바뀌지 않는다.
  - 워크트리 경로가 `.claude/` 아래가 아니면 SwiftLint 대상이 될 수 있다. 스크래치 경로를 쓴다.

### 6. README "새 앱으로 복제할 때 바꿀 곳" 갱신
- 파일: `README.md`(155-163행), `AppConstants.swift:15-19,24-28`의 주석
- 변경:
  - 목록을 `Scripts/rename.sh` 사용법으로 바꾼다.
  - 스크립트가 하지 않는 일을 남긴다: Firebase plist, ClientKeys, 번들 ID 등록, 폴더 이름, 옛 워크스페이스 삭제.
  - `AppConstants`의 "여기만 바꾸면 된다" 주석을 "`Scripts/rename.sh`로 바꾼다"로 고친다.
- 검증: 문서와 주석만 바뀐다. `xcbuild.sh build` 통과.

## 테스트 전략

- Swift 단위 테스트는 추가하지 않는다. 두 스크립트는 셸 도구이고, 대상 코드(`ProjectDescriptionHelpers`)는 테스트 타깃이 없는 매니페스트다.
- 검증은 3단계와 5단계의 종단 확인으로 한다. 두 스크립트의 결과가 `tuist generate`와 `xcbuild.sh build`/`test`를 통과하는지, 실패 분기(중복, 잘못된 이름, 더러운 트리)가 exit 1이고 파일을 건드리지 않는지 본다.
- 스캐폴드가 만든 `{{ name }}Tests.swift`는 새 모듈의 테스트 타깃이 비어 있지 않게 하는 최소 테스트다. 워크스페이스 테스트 액션에서 실제로 실행되는지 3단계에서 확인한다.
- 수정이 필요한 기존 테스트는 없다. rename이 `App/Tests`를 치환하지만 스크립트를 실행했을 때의 일이고, 저장소에 커밋되는 변경은 아니다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| `-p`를 준 scaffold가 템플릿 탐색이나 경로 기준을 예상과 다르게 처리함 | 중 | 2단계 임시 실행에서 확인한다. 다르면 `cd "$root"` 후 `-p` 없이 실행한다 |
| 빈 enum Route가 Hashable 합성이나 lint에 걸림 | 중 | case 하나를 둔 Route로 바꾼다(구현 중 확인) |
| 템플릿이 코드베이스 변경(`Project.feature` 시그니처, DesignSystem API)을 따라가지 못해 조용히 깨짐 | 중 | README에 "Project+Templates.swift를 바꾸면 `new-module.sh`로 한 번 생성해 본다"를 적는다. CI 잡은 범위 밖이며 후속 후보다 |
| rename의 부분 문자열 치환이 의도하지 않은 단어를 바꿈(옛 이름이 흔한 단어일 때) | 저(현재 이름은 고유함) | 치환 전에 대상 파일 수와 출현 수를 출력한다. 작업 트리가 깨끗해야 하므로 `git diff`로 검토하고 `git checkout .`으로 되돌릴 수 있다 |
| `Package.swift`의 `name` 변경이 `Tuist/.build` 캐시와 맞지 않아 install이 실패함 | 저 | 다음 할 일 안내에 `tuist install`을 포함한다. 5단계 검증에서 확인한다 |
| 마커 주석을 누가 지우거나 옮김 | 저 | 래퍼가 마커가 정확히 한 개씩 있는지 확인하고, 없으면 중단한다. 마커 주석에 용도를 적는다 |
| perl 삽입 시 들여쓰기나 trailing comma가 SwiftFormat 결과와 다름 | 저 | 3단계 검증에 `swiftformat --lint Tuist/ProjectDescriptionHelpers/Module.swift`를 추가한다 |

## 롤백

- 단계마다 커밋 하나다. 문제가 있는 단계의 커밋을 `git revert`한다.
- 1단계의 `.core(String)`은 추가만 하는 변경이다. 쓰는 곳이 없으면 되돌려도 기존 모듈에 영향이 없다.
- 두 스크립트와 템플릿은 새 파일이다. 지우면 원래 상태가 된다.
- 사용자가 실행한 rename은 깨끗한 트리에서만 돌므로 `git checkout . && git clean -fd`로 되돌린다.
