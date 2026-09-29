# UI 스모크 테스트·의존성 검사·SPM 자동화·키 목록 정리

## 목표

- `tuist inspect dependencies`가 로컬과 CI에서 exit 0으로 끝난다. CI는 암묵적·중복 의존이 생기면 실패한다.
- 앱에 두 번째 탭(빈 자리표시자)이 생긴다. `TuistAppUITests` 타깃의 스모크 테스트 두 개가 워크스페이스 스킴 `xcbuild.sh test`에서 통과한다.
  - 탭 전환: 두 번째 탭 → 홈 탭으로 돌아와 스텁 항목이 보인다.
  - 딥링크: 두 번째 탭에 있을 때 `<scheme>://home`을 열면 홈 탭이 선택되고 스텁 항목이 보인다.
- UI 테스트는 launch argument 하나로 앱의 `itemRepository`를 DEBUG 전용 스텁으로 바꿔 네트워크에 의존하지 않는다. Release 빌드에는 스텁 코드가 없다.
- Info.plist에 넣는 클라이언트 키 목록을 한 곳(`AppConstants.clientKeys`)에서 선언한다. 생성되는 Info.plist 키 집합은 이전과 같다.
- 저장소 루트의 `renovate.json`이 SPM(`Tuist/Package.swift`)과 `mise.toml`을 월 1회 묶음으로 업데이트한다. Actions는 계속 Dependabot이 맡는다.
- `Scripts/module-graph.sh`가 모듈 그래프 SVG를 `docs/images/module-graph.svg`로 만들고, README가 이 이미지를 보여준다.

## 범위 밖

- `enforceExplicitDependencies` 제거. 유지합니다(결정 사항 참고).
- `MAP_SDK_KEY`와 `ANALYTICS_APP_KEY` 제거. 09-23 계획에서 자리표시자로 두기로 한 결정을 유지합니다.
- 로컬 `Configurations/ClientKeys.xcconfig:21`의 `CRASH_REPORTING_DSN`. 추적되지 않는 로컬 파일이고 09-22 계획에서 이미 정리하기로 한 키입니다. 사용자가 직접 지웁니다.
- 두 번째 탭의 딥링크 세그먼트(`DeepLinkParser`)와 실제 화면 내용.
- CI에서 그래프를 생성하거나 오래된 그래프를 검사하는 일. README 이미지는 수동으로 갱신합니다.
- Renovate GitHub App 설치. 외부 서비스 권한을 주는 일이라 사용자가 직접 합니다.
- feature 템플릿(`Project.feature`)의 *Testing 자동 연결. inspect가 지적하지 않았습니다.

## 전제

구현 세션은 이 문서만 읽습니다.

**환경**
- 최소 iOS 17.0, Swift 6.0, Tuist 4.208.0(`mise.toml`), Xcode 27.

**의존성 검사**
- `tuist inspect dependencies [--only implicit|redundant]`는 4.125.0에 도입됐고 계정이 필요 없습니다(로컬 약 3초). 문제가 있으면 exit ≠ 0입니다.
  - 파이프로 넘기면 exit가 가려집니다. CI 스텝에서 파이프로 넘기지 마세요.
  - 제안에 있던 `inspect redundant-imports`는 deprecated입니다.
- 현재 결과(2026-09-29 로컬 실행):
  - `TuistAppTests implicitly depends on: Data, Diagnostics, Domain, FeatureFlags, FirebaseRemoteConfig, HomeInterface, Navigation, Networking, Persistence, Tracking`
    - `App/Tests/*.swift`가 이 모듈들을 직접 `import`하지만, `App/Project.swift`의 `testDependencies`에는 `.testing(.diagnostics)`, `.testing(.domain)`, `.testing(.core("Persistence"))`만 있습니다.
  - `NavigationTests redundantly depends on: NavigationTesting`, `TrackingTests redundantly depends on: TrackingTesting`
    - `Project.core`([Project+Templates.swift:136](Tuist/ProjectDescriptionHelpers/Project+Templates.swift:136) `testingTarget`)가 `hasTestingSupport`일 때 자기 *Testing을 테스트 타깃에 자동으로 붙입니다.
    - 자기 *Testing을 import하는 테스트 파일 수: Auth 3, Networking 1, Persistence 1, Diagnostics 1, FeatureFlags 1, Domain 1, **Navigation 0, Tracking 0**. 두 모듈의 *Testing은 다른 모듈 테스트(예: Home의 `SpyRouter`)가 씁니다.
- `lint` 잡([ci.yml:31-52](.github/workflows/ci.yml:31))은 mise만 설치하고 `tuist install`을 거치지 않습니다. inspect는 외부 의존성(Firebase)까지 그래프를 읽으므로 셋업(`./.github/actions/setup`)을 거친 잡에 넣어야 합니다.
- README에는 `enforceExplicitDependencies` 언급이 두 군데 있습니다(292, 378행). 템플릿 주석에도 있습니다(Project+Templates.swift:25, 301, 332).

**앱 구조**
- 탭: [AppTab.swift](App/Sources/Navigation/AppTab.swift)(`case home`, `title: LocalizedStringKey`, `icon: AppIcon`).
  - 루트 화면 분기는 [TabRootView.swift](App/Sources/Navigation/TabRootView.swift)의 `root` switch입니다.
  - [RootView.swift](App/Sources/Navigation/RootView.swift)는 `AppTab.allCases`를 돌며 탭을 만듭니다. `AppRouter.selectedTab`의 기본값은 `.home`입니다([AppRouter.swift:20](App/Sources/Navigation/AppRouter.swift:20)).
- `AppIcon`([AppIcon.swift](Modules/Core/DesignSystem/Sources/Views/AppIcon.swift))에는 `more = "ellipsis"`, `empty = "tray"` 등이 이미 있습니다. 새 아이콘 케이스를 만들지 않습니다.
- 빈 화면에는 `AppStatusView.empty(title:)`(DesignSystem)를 씁니다. HomeView가 쓰는 방식과 같습니다.
- 딥링크 진입점은 `.onOpenURL { appDelegate.router.handle($0) }`([TuistAppApp.swift:18](App/Sources/TuistAppApp.swift:18))입니다. `tuistapp://home`은 `DeepLink(tab: .home, path: [])`가 됩니다([DeepLinkParser.swift](App/Sources/Navigation/DeepLinkParser.swift)).
- 스킴 값의 출처는 `AppConstants.urlScheme = "tuistapp"`([AppConstants.swift:29](Tuist/ProjectDescriptionHelpers/AppConstants.swift:29))이고, `Scripts/rename.sh`가 바꿉니다. UI 테스트 코드에 `"tuistapp"`를 직접 쓰지 않습니다.
- [AppContainer.swift](App/Sources/DI/AppContainer.swift)는 `@MainActor`입니다. `itemRepository`는 `CachedItemRepository`로 고정 조립됩니다(대략 85-91행).
  - `startClearingItemCache(of: cachedItemRepository, …)`는 구체 타입을 받으므로 스텁으로 바꿔도 그대로 둡니다.
  - launch argument를 읽는 코드는 지금 없습니다.
- `Module.validateAppDependencies`([Module.swift:334](Tuist/ProjectDescriptionHelpers/Module.swift:334))가 앱이 *Testing에 의존하는 것을 `fatalError`로 막습니다. 그래서 `StubItemRepository`(DomainTesting)는 앱에서 쓸 수 없습니다.
- `Item`은 `public init(id: String, title: String)`(Domain)이 있어 앱에서 만들 수 있습니다.
- 첫 실행 시스템 알림: `AppDelegate`는 `registerForRemoteNotifications()`만 부르고 `requestAuthorization`은 부르지 않습니다. 권한 알림이 UI 테스트를 가리지 않습니다.
- 화면 쪽 `accessibilityIdentifier`는 0건입니다.

**타깃·스킴**
- 앱 타깃과 유닛 테스트 타깃은 [Project+Templates.swift](Tuist/ProjectDescriptionHelpers/Project+Templates.swift) `Project.app`(186-222행)이 만듭니다.
- 워크스페이스 스킴은 [Scheme+Workspace.swift](Tuist/ProjectDescriptionHelpers/Scheme+Workspace.swift) `Scheme.workspace()`입니다.
  - `tests` 배열이 테스트 액션에 들어가고, 빌드 액션에는 테스트 타깃이 없습니다(Release 빌드가 테스트 타깃을 컴파일하지 않게 하려는 것).
  - `xcbuild.sh`는 이 스킴(`TuistApp-Workspace`)을 씁니다.

**UI 테스트 API**
- `XCUIApplication.launchArguments`(iOS 9+). 앱은 `ProcessInfo.processInfo.arguments`로 읽습니다.
- `XCUIApplication`의 URL 열기는 ObjC `openURL:`이고 iOS 16.4+라 폴백이 필요 없습니다. Swift 이름(`open(_:)`)은 구현 중 확인합니다.
- `XCUIApplication`은 `@MainActor`입니다. Swift 6에서는 `XCTestCase` 테스트 메서드(또는 클래스)에 `@MainActor`를 붙입니다.
- UI 테스트는 XCTest로 씁니다. 나머지 테스트는 Swift Testing입니다.
- Tuist 선언: `product: .uiTests`, `dependencies: [.target(name: <앱>)]`. 프로세스 밖에서 돌아 앱 코드를 `import`할 수 없습니다.

**Info.plist**
- [Settings+Common.swift:64-97](Tuist/ProjectDescriptionHelpers/Settings+Common.swift:64) `InfoPlist.runnable`이 `"ANALYTICS_APP_KEY": "$(ANALYTICS_APP_KEY)"`와 `"MAP_SDK_KEY": "$(MAP_SDK_KEY)"`를 직접 적습니다.
- 이 함수는 앱과 모든 데모 앱이 씁니다. 키 목록 문서는 `Configurations/ClientKeys.xcconfig.example`입니다.

**SPM·도구 업데이트**
- `Tuist/Package.swift`의 외부 패키지는 swift-openapi-runtime, swift-openapi-urlsession, swift-http-types, firebase-ios-sdk(`from: 12.19.2`, "13은 별도 검토" 주석) 넷입니다.
  - `#if TUIST` 블록이 있습니다. `Tuist/Package.resolved`는 커밋되어 있습니다.
- `.github/dependabot.yml`은 github-actions만 다루고, 주석에 "SPM과 mise.toml 도구는 대상이 아니다"라고 적혀 있습니다.
- Renovate `swift` 매니저([문서](https://docs.renovatebot.com/modules/manager/swift/))와 `mise` 매니저([문서](https://docs.renovatebot.com/modules/manager/mise/))는 현행입니다.
  - swift 매니저가 `Package.resolved`를 갱신하는지는 문서에서 확인하지 못했습니다.
- CI SPM 캐시 키는 `Tuist/Package.resolved`, `Tuist/Package.swift`, `mise.toml`의 해시입니다(`.github/actions/setup/action.yml`).

**그래프**
- `tuist graph` 옵션: `-f dot|json|png|svg`, `-t`(테스트 타깃 제외), `-d`(외부 의존 제외), `--no-open`, `-o <dir>`. 출력 파일 이름은 `graph.<ext>`입니다.
- png/svg는 graphviz가 필요합니다. graphviz가 없으면 Tuist가 **Homebrew로 자동 설치**합니다. 출력 디렉터리가 없으면 실패합니다.
- `.gitignore:37-40`이 `graph.dot/png/svg/json`을 무시합니다. 경로와 상관없이 매칭되므로 커밋할 파일은 이름을 바꿔야 합니다.

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 의존성 검사 명령 | `tuist inspect dependencies`(implicit + redundant 둘 다) | 제안된 `redundant-imports`는 deprecated입니다. 사용자가 두 종류 모두 검사하기로 했습니다 |
| inspect를 돌릴 CI 잡 | `release-build`의 셋업 뒤, Release 빌드 앞 | **제안(lint 잡)과 다릅니다.** lint는 `tuist install`을 하지 않아 외부 의존 그래프를 못 읽습니다. `build-test`에 넣으면 inspect가 실패할 때 테스트 결과가 빠집니다. release-build는 이미 셋업을 거치고 병렬로 돕니다 |
| `enforceExplicitDependencies` | 유지 | 플랫폼 조사는 deprecated라고 했지만, README 378행대로 `generate` 시점에 로컬에서 바로 막아 줍니다. inspect는 CI 보완입니다. 구현 중 `tuist generate` 출력에 deprecation 경고가 보이면 "구현 중 확인" 결과로 이 문서에 기록하고, 제거는 후속으로 넘깁니다 |
| 중복 *Testing 해소 | (9단계에서 대체) 자기 *Testing 자동 연결을 없애고 쓰는 모듈만 `.testing(...)` 으로 명시 | 자동 연결은 새 모듈(스캐폴드)에서도 중복 의존을 만든다. 템플릿 프로젝트라 한 규칙(import 하는 것만 명시)으로 통일한다 |
| 앱 테스트의 암묵적 의존 | `App/Project.swift` `testDependencies`에 10개를 명시 | `import`하는 모듈을 적는다는 기존 규약(Project+Templates.swift:301 주석)을 따릅니다 |
| UI 테스트 스텁 주입 | App/Sources에 `#if DEBUG`로 감싼 고정 결과 `ItemRepository`. launch argument가 있을 때만 `AppContainer`가 이것을 씁니다 | 사용자 선택. *Testing 금지 규칙을 유지하고 Release에는 들어가지 않습니다 |
| 두 번째 탭 | `AppTab.more`(제목 "더보기", 아이콘 `.more`). 루트는 `AppStatusView.empty` 자리표시자 | 사용자가 "빈 탭을 하나 더"로 선택했습니다. DesignSystem에 새 API가 필요 없습니다 |
| launch argument 공유 | `App/Sources/DI/UITestLaunchArgument.swift`(enum)를 앱과 UI 테스트 타깃 양쪽 sources에 넣습니다 | UI 테스트는 앱을 import할 수 없습니다. 문자열을 두 곳에 두지 않기 위해서입니다 |
| UI 테스트의 URL 스킴 | UI 테스트 타깃 Info.plist에 `APP_URL_SCHEME: AppConstants.urlScheme`을 넣고 테스트가 번들에서 읽습니다 | `rename.sh`가 바꾸는 단일 출처를 유지합니다 |
| UI 테스트 실행 위치 | 워크스페이스 스킴 테스트 액션에 추가합니다(`build-test` 잡에서 돎) | 스모크 두 개라 비용이 작습니다. 별도 스킴·잡은 두지 않습니다 |
| 요소 찾기 | 탭은 탭 바 버튼 라벨로 찾습니다. 두 번째 탭 자리표시자에만 `accessibilityIdentifier`를 붙입니다. 스텁 항목은 제목 텍스트로 찾습니다 | 식별자가 0건이라 필요한 곳만 최소로 추가합니다 |
| 클라이언트 키 목록 | `AppConstants.clientKeys: [String]`에 선언합니다. `runnable`이 이것을 `"$(KEY)"`로 펼칩니다 | 제안대로입니다. `API_BASE_URL`과 `LOG_LEVEL`은 환경 설정이라 목록에 넣지 않습니다 |
| SPM·도구 자동화 | Renovate(`swift` + `mise` 매니저만, 월 1회 묶음, firebase 메이저 업데이트 차단) | 사용자 선택. Tuist 프로젝트에서 흔한 방식이고 mise까지 다룹니다. Actions는 Dependabot에 남겨 중복 PR을 막습니다 |
| 그래프 | `Scripts/module-graph.sh` → `tuist graph -f svg -t -d --no-open` → `docs/images/module-graph.svg`. README "구조" 절에 이미지를 넣습니다 | 사용자 선택(README에만). 테스트 타깃과 외부 의존을 빼서 모듈 구조만 보입니다. 스크립트가 graphviz 유무를 먼저 검사해 brew 자동 설치를 막습니다 |

## 변경 계획

### 1. 암묵적·중복 의존 정리

**파일**
- `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`
- `Modules/Core/Navigation/Project.swift`
- `Modules/Core/Tracking/Project.swift`
- `App/Project.swift`

**변경**
- `Project.core`에 `testsUseTestingSupport: Bool = true`를 추가합니다.
  - `false`면 `.testTarget`에 `testingTarget`을 넣지 않습니다. 데모 연결(`demoDependencies + testingTarget`)은 그대로 둡니다.
  - doc 주석에 "자기 *Testing을 테스트가 import하지 않으면 false. `tuist inspect dependencies`가 중복으로 잡는다"를 적습니다.
- Navigation과 Tracking의 `Project.swift`에 `testsUseTestingSupport: false`를 넣습니다.
- `App/Project.swift` `testDependencies`에 다음을 추가합니다. 각 항목에 쓰는 테스트 파일을 주석으로 답니다(기존 스타일).
  - `.module(.data)`, `.module(.diagnostics)`, `.module(.domain)`, `.module(.featureFlags)`, `.module(.featureInterface("Home"))`, `.module(.navigation)`, `.module(.networking)`, `.module(.core("Persistence"))`, `.module(.tracking)`, `.external(name: "FirebaseRemoteConfig")`
  - 정확한 헬퍼 이름은 `Module.swift`를 보고 맞춥니다.

**검증**
- `tuist install && tuist generate --no-open`이 통과합니다.
- `tuist inspect dependencies; echo $?`가 0입니다.
- `./.claude/scripts/xcbuild.sh test`가 통과합니다.
- 구현 중 확인: 호스트 앱에 이미 링크된 정적 프레임워크를 테스트 타깃이 다시 의존할 때 중복 심볼 경고나 에러가 나는지. 나면 이 문서에 기록하고 멈춰서 사용자에게 묻습니다.

### 2. CI에 의존성 검사 추가

**파일**
- `.github/workflows/ci.yml`
- `README.md`

**변경**
- `release-build` 잡의 셋업 뒤, Release 빌드 앞에 스텝 `의존성 검사 (tuist inspect)`를 넣고 `run: tuist inspect dependencies`를 실행합니다.
  - 스텝 위 주석: 왜 lint가 아닌지(셋업 필요), 왜 build-test가 아닌지(테스트 결과 보존).
  - 파일 상단 주석의 잡 설명도 맞춥니다.
- README "CI" 절을 갱신합니다.
  - 잡 표의 `release-build` 행에 "암묵적·중복 의존 검사"를 추가합니다.
  - "로컬에서 같은 검사를 재현하려면" 목록에 `tuist inspect dependencies`를 추가합니다.
  - `enforceExplicitDependencies`(generate 시점)와 inspect(CI)의 역할 차이를 한 줄로 적습니다.

**검증**
- `actionlint`가 로컬에 있으면 돌립니다. 없으면 YAML 문법만 확인합니다(`ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml")'`).
- 실제 CI 결과는 PR에서 확인합니다.

### 3. 두 번째 탭(자리표시자) 추가

**파일**
- `App/Sources/Navigation/AppTab.swift`
- `App/Sources/Navigation/TabRootView.swift`

**변경**
- `AppTab`에 `case more`를 추가합니다(`title: "더보기"`, `icon: .more`). doc 주석: "UI 스모크 테스트의 탭 전환 대상인 자리표시자. 실제 화면이 생기면 교체한다."
- `TabRootView.root`에 `.more` 분기를 추가합니다.
  - `AppStatusView.empty(title:)`에 `.navigationTitle`을 붙입니다.
  - 식별자(`accessibilityIdentifier`)는 이 단계에서 붙이지 않습니다. 상수를 둘 공유 enum이 4단계에서 생기므로 4단계에서 붙입니다.
  - 문자열은 기존 `AppTab.title`처럼 `LocalizedStringKey` 리터럴을 씁니다. App 타깃에 String Catalog가 있는지 구현 중 확인하고, 있으면 항목을 추가합니다.
- `DeepLinkParser`는 건드리지 않습니다(범위 밖).

**검증**
- 빌드와 기존 테스트가 통과합니다.
- `AppRouterTests`와 `DeepLinkParserTests` 중 `allCases` 개수나 탭 하나를 전제로 한 단언이 있으면 새 탭에 맞게 고칩니다. `grep -n "allCases\|\.home" App/Tests`로 확인합니다.

### 4. UI 테스트용 스텁 경로

**파일**
- 새로 만듦: `App/Sources/DI/UITestLaunchArgument.swift`, `App/Sources/DI/UITestItemRepository.swift`
- 수정: `App/Sources/DI/AppContainer.swift`
- 새 테스트: `App/Tests/AppContainerItemRepositoryTests.swift`

**변경**
- `UITestLaunchArgument`(`enum`, `#if DEBUG` 없이 상수만 둠):
  - `static let stubItems = "-UITestStubItems"`
  - 스텁 항목 제목 상수 `static let stubItemTitle`
  - 두 번째 탭 자리표시자의 식별자 상수
  - 앱과 UI 테스트 타깃이 함께 컴파일한다는 주석
- `UITestItemRepository`(`#if DEBUG` 전체): `ItemRepository`를 따르는 `struct`입니다. `Item(id:title:)` 하나(제목은 위 상수)를 돌려주고, `Sendable`입니다.
- `AppContainer`에 정적 팩토리 `makeItemRepository(default: any ItemRepository, arguments: [String]) -> any ItemRepository`를 둡니다.
  - `#if DEBUG`이고 `arguments`에 `stubItems`가 있으면 `UITestItemRepository()`를 돌려주고, 아니면 `default`를 돌려줍니다.
  - `init`에서는 `itemRepository = Self.makeItemRepository(default: cachedItemRepository, arguments: ProcessInfo.processInfo.arguments)`로 씁니다. 캐시 비우기 연결은 그대로 `cachedItemRepository`를 씁니다.
  - 기존 `makeLocalDatabase` 같은 정적 팩토리 패턴을 따릅니다.
- `TabRootView`의 `.more` 자리표시자에 `.accessibilityIdentifier(UITestLaunchArgument.<식별자 상수>)`를 붙입니다(`App/Sources/Navigation/TabRootView.swift`).
- 강제 언래핑이나 싱글턴을 새로 만들지 않습니다.

**검증**
- Debug 테스트가 통과합니다.
- `./.claude/scripts/xcbuild.sh build -configuration Release`가 통과합니다. Release에서 `UITestItemRepository` 참조가 컴파일에서 빠지는지가 핵심입니다.

### 5. UI 테스트 타깃과 스모크 테스트

**파일**
- `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`(`Project.app`)
- `Tuist/ProjectDescriptionHelpers/Scheme+Workspace.swift`
- 새로 만듦: `App/UITests/TuistAppSmokeUITests.swift`
- `README.md`("스킴" 또는 "CI" 절)

**변경**
- `Project.app`의 targets에 UI 테스트 타깃을 추가합니다.
  - `"\(name)UITests"`, `product: .uiTests`, bundleId `AppConstants.bundleID(for: "\(name)UITests")`
  - sources: `["UITests/**", "Sources/DI/UITestLaunchArgument.swift"]`
  - infoPlist: `.extendingDefault(with: ["APP_URL_SCHEME": .string(AppConstants.urlScheme)])`
  - `dependencies: [.target(name: name)]`
  - 비공개 `Target` 헬퍼(`uiTestTarget(for:)`)로 만들어 `testTarget`과 나란히 둡니다.
- `Scheme.workspace()`의 `tests`에 `"\(AppConstants.appName)UITests"`를 추가합니다. `codeCoverageTargets`는 그대로 둡니다.
- 테스트 클래스(`@MainActor final class …: XCTestCase`):
  - `setUp`: `continueAfterFailure = false`, `app.launchArguments = [UITestLaunchArgument.stubItems]`, `app.launch()`
  - `testSwitchingTabs`: 탭 바의 "더보기" 탭 → 자리표시자 식별자 존재 → "홈" 탭 → 스텁 제목 `staticTexts` 존재. `waitForExistence(timeout:)`를 씁니다.
  - `testDeepLinkSelectsHomeTab`: "더보기" 탭 → 번들 Info.plist의 `APP_URL_SCHEME`으로 `"<scheme>://home"` URL을 만들어 엽니다(`guard`/`XCTUnwrap`) → 스텁 제목이 보입니다.
  - 탭 라벨 문자열("홈", "더보기")은 파일 하단 `private enum`에 모읍니다.
- README: 워크스페이스 스킴 테스트에 UI 스모크 테스트가 포함된다는 것, `-UITestStubItems`가 하는 일, UI 테스트만 도는 명령을 적습니다.

```bash
./.claude/scripts/xcbuild.sh test -only-testing:TuistAppUITests
```

**검증**
- 위 `-only-testing` 명령이 통과합니다.
- 전체 `xcbuild.sh test`와 Release 빌드가 통과합니다.
- `tuist inspect dependencies`가 exit 0입니다(uiTests→app 오탐은 Tuist 수정 이력 8811이 있습니다. 오탐이 나면 기록합니다).
- 구현 중 확인:
  - `open(_:)`로 커스텀 스킴을 열 때 "열겠습니까" 시스템 알림이 뜨는지. 뜨면 `addUIInterruptionMonitor`나 springboard 버튼 탭으로 처리합니다.
  - 탭 바 버튼 라벨이 한국어 그대로 노출되는지(시뮬레이터 언어).

### 6. 클라이언트 키 목록 한 곳 선언

**파일**
- `Tuist/ProjectDescriptionHelpers/AppConstants.swift`
- `Tuist/ProjectDescriptionHelpers/Settings+Common.swift`
- `Configurations/ClientKeys.xcconfig.example`(주석만)

**변경**
- `AppConstants`에 `public static let clientKeys = ["ANALYTICS_APP_KEY", "MAP_SDK_KEY"]`를 추가합니다.
  - doc: "ClientKeys.xcconfig.example 과 같은 목록. 키를 추가·삭제할 때 두 곳을 함께 바꾼다. 앱과 데모 앱 Info.plist 에 `$(KEY)` 로 들어간다."
- `InfoPlist.runnable`에서 두 줄을 지우고, `for key in AppConstants.clientKeys { plist[key] = .string("$(\(key))") }`로 채웁니다.
- `.example` 상단 주석에 "목록을 바꾸면 AppConstants.clientKeys 도 바꾼다"를 한 줄 추가합니다.

**검증**
- 변경 전과 후에 Debug 빌드한 앱의 Info.plist 키를 비교합니다. 둘이 같아야 합니다.

```bash
plutil -p <빌드된 TuistApp.app>/Info.plist | sort
```

- 데모 앱(HomeDemo)도 같은 방식으로 한 번 확인합니다.

### 7. Renovate 설정

**파일**
- 새로 만듦: `renovate.json`
- 수정: `.github/dependabot.yml`(주석), `README.md`(CI 절)

**변경**
- `renovate.json`:
  - `"$schema"`, `"enabledManagers": ["swift", "mise"]`(Actions와 중복되지 않게)
  - `"schedule"`은 월 1회(Renovate 문법, 예: `["* 0-3 1 * *"]`), `"timezone": "Asia/Seoul"`
  - 모든 업데이트를 PR 하나로 묶는 `packageRules`(`groupName`)
  - firebase-ios-sdk 메이저 업데이트는 `"enabled": false`로 막고 이유를 `description`에 적습니다("13은 별도 검토", Package.swift 주석과 같음). 패키지 이름 매칭 형식(`matchPackageNames`)은 swift 매니저 문서를 보고 구현 중 확인합니다.
  - `"commitMessagePrefix"`는 기존 Dependabot 관례(`ci:` 대신 `build(deps):` 등)에 맞춰 구현자가 정하고 README에 적습니다.
- `dependabot.yml` 주석: "SPM과 mise.toml은 Renovate(renovate.json)가 맡는다."
- README CI 절:
  - Renovate가 무엇을 언제 올리는지, Firebase 메이저를 막아 둔 이유
  - **Renovate GitHub App 설치는 사용자가 한다**는 안내
  - `Package.resolved`가 갱신되지 않으면 로컬에서 `tuist install --update`로 보완한다는 것

**검증**
- 구현 중 확인(패키지 다운로드가 필요하므로 사용자에게 먼저 묻습니다):

```bash
npx --yes --package renovate -- renovate-config-validator
```

- 실제 동작은 앱 설치 후 첫 Dependency Dashboard 이슈와 PR로 확인합니다.

### 8. 모듈 그래프 스크립트와 README

**파일**
- 새로 만듦: `Scripts/module-graph.sh`, `docs/images/module-graph.svg`
- 수정: `README.md`

**변경**
- 스크립트(`set -euo pipefail`, 기존 Scripts 스타일):
  - `command -v dot`가 없으면 "graphviz가 필요합니다: brew install graphviz"를 출력하고 exit 1. Tuist의 brew 자동 설치를 막습니다.
  - 임시 디렉터리를 만들고 `tuist graph -f svg -t -d --no-open -o "$tmp"`를 실행합니다.
  - 결과 `"$tmp/graph.svg"`를 `docs/images/module-graph.svg`로 옮깁니다. `graph.svg`라는 이름이 `.gitignore`에 걸리지 않게 하려는 것입니다.
- README "구조" 절에 `![모듈 의존 그래프](docs/images/module-graph.svg)`와 갱신 명령(`Scripts/module-graph.sh`)을 넣습니다. 모듈을 추가·변경하면 다시 돌린다는 안내를 "모듈 추가" 절에 한 줄 넣습니다.

**검증**
- 스크립트를 실행하면 SVG가 생기고 `git status`에 보입니다(무시되지 않음).
- README 미리보기에서 이미지가 보입니다.
- 구현 중 확인: SVG 크기가 크면(수백 KB 이상) png로 바꿀지 사용자에게 묻습니다.

### 9. 자기 *Testing 자동 연결 제거 (계획 추가, 2026-09-29 사용자 승인)

1단계의 `testsUseTestingSupport` 는 "모듈 테스트는 자기 *Testing 을 쓴다"는 가정을 유지한 채 예외를 덜어낸 것이다.
이 가정은 새 모듈(스캐폴드 테스트·데모가 *Testing 을 import 하지 않음)에서도 깨져 `new-module.sh --testing` 으로 만든 모듈이
`tuist inspect dependencies` 에서 중복 의존으로 실패한다. "import 하는 것만 명시한다" 한 규칙으로 통일한다.

- 파일: `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`, `Tuist/ProjectDescriptionHelpers/Module.swift`,
  `Modules/Core/{Auth,Networking,Persistence,Diagnostics,FeatureFlags,Domain,Navigation,Tracking}/Project.swift`,
  `Tuist/Templates/{core,feature}/Project.stencil`(필요 시 주석만), `README.md`("모듈 추가"), `Scripts/new-module.sh`(안내 문구)
- 변경:
  - `Project.core`: `testsUseTestingSupport` 제거. 테스트·데모에 `testingTarget` 을 붙이지 않는다.
  - `Project.feature`: 테스트·데모의 `localSupport` 에서 자기 *Testing 을 뺀다(Interface 자동 연결은 유지. 스캐폴드가 import 한다).
  - `Module.validateDependencies`: 지원 타깃(테스트·데모)이 **자기 모듈의 *Testing** 에 의존하는 것은 `mayDepend` 없이 허용한다.
    Core 는 `.testing(.domain)` 이 자기 자신(.domain → .domain)으로 풀려 규칙에 걸리기 때문이다.
  - 자기 *Testing 을 import 하는 6개 모듈에 `testDependencies: [.testing(<자기>)]` 를 명시한다. Navigation·Tracking 은 1단계 플래그만 지운다.
  - 템플릿 주석(Project+Templates.swift 25행 "Tests·Demo → 구현·Interface·Testing")과 README 를 새 규칙으로 고친다.
- 검증: generate, `tuist inspect dependencies` exit 0, 전체 테스트. 구현 중 확인: 같은 프로젝트를 `.project(path:)` 로 가리키는 자기 *Testing 참조를 Tuist 가 받아들이는지.

### 10. 템플릿 검증 스크립트와 CI (계획 추가, 2026-09-29 사용자 승인: 빌드 포함)

- 파일: 새로 만듦 `Scripts/verify-templates.sh`, `.github/workflows/templates.yml` / 수정 `README.md`
- 변경:
  - 스크립트: 작업 트리를 임시 디렉터리로 복사(`.git`, 생성물, `Tuist/.build` 제외. `Tuist/.build` 는 심볼릭 링크로 재사용) →
    `new-module.sh core <Name> --demo --testing --resources`, `new-module.sh feature <Name> --demo --testing --resources` →
    `tuist generate` → `tuist inspect dependencies` → 워크스페이스 스킴 빌드 → 새 두 모듈의 테스트 실행. 원본 저장소는 건드리지 않는다.
    커밋 전 템플릿 변경도 검사하도록 git 워크트리가 아니라 작업 트리 복사를 쓴다.
  - 워크플로: `Tuist/**`, `Scripts/new-module.sh`, `Scripts/verify-templates.sh`, `mise.toml`, 이 워크플로가 바뀐 PR 과 main 푸시에서만 돈다.
    셋업은 `./.github/actions/setup` 재사용. 경로 필터가 있어 required check 로 걸면 PR 이 대기 상태로 막힌다는 점을 README 에 적는다.
- 검증: 로컬에서 스크립트가 통과한다. 템플릿을 일부러 깨뜨리면(예: 자동 연결 복원) 실패하는지 한 번 확인하고 되돌린다.

### 10b. feature 스캐폴드를 MVVM 골격으로 (계획 추가, 2026-09-29 사용자 승인)

10단계 스크립트가 찾은 문제: feature 스캐폴드가 선언한 의존을 쓰지 않아 inspect 가 실패한다
(`<Name> redundantly depends on: Navigation, <Name>Interface`, `<Name>Tests redundantly depends on: <Name>`). core 템플릿은 통과.

- 파일: `Tuist/Templates/feature/{feature.swift, View.stencil, ViewModel.stencil(새로 만듦), Route.stencil, Tests.stencil, Fixtures.stencil, DemoApp.stencil, Project.stencil, Localizable.xcstrings.stencil}`
- 변경: Home 과 같은 패턴. `<Name>ViewModel`(@MainActor @Observable, `any Routing` 주입, `showDetail()` 이 `<Name>Route.detail` 을 push),
  View 는 뷰모델을 받아 버튼으로 `showDetail()` 을 부른다. 테스트는 NavigationTesting 의 `SpyRouter` 로 push 를 확인한다
  (`testDependencies: [.testing(.navigation)]`). Route 의 자리표시 case 는 `main` → `detail` 로 바꾼다(첫 화면에서 가는 곳).
- 검증: `Scripts/verify-templates.sh` 통과.

## 테스트 전략

- **새 유닛 테스트** `AppContainerItemRepositoryTests`(Swift Testing, `@MainActor`)
  - `stubItems` 인자가 있으면 `UITestItemRepository`가 선택되고 `fetchItems()`가 스텁 항목을 돌려줍니다(DEBUG 분기).
  - 인자가 없으면 넘긴 `default`를 그대로 돌려줍니다. `default`에는 DomainTesting의 `StubItemRepository`를 쓰고, 결과로 구별합니다.
- **새 UI 테스트** `TuistAppSmokeUITests`
  - 탭 전환: `RootView`의 `TabView` 바인딩과 `TabRootView.root`의 `.more`/`.home` 분기
  - 딥링크: `onOpenURL` → `AppRouter.handle` → `selectedTab = .home`
  - 두 테스트 모두 `AppContainer`의 스텁 분기를 E2E로 지납니다.
- **의존성 검사**: `tuist inspect dependencies`가 CI에서 그래프 회귀를 막습니다.
- **수정 가능성이 있는 기존 테스트**
  - `AppRouterTests`, `DeepLinkParserTests`: 탭이 하나라는 전제가 있으면 고칩니다.
  - `AppContainer*Tests`: init 시그니처는 바꾸지 않으므로 영향이 없을 것으로 예상합니다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| 앱 테스트 타깃에 정적 프레임워크를 명시하면 호스트 앱과 중복 링크(중복 심볼, 런타임 클래스 중복 경고)가 생김 | 중 | 1단계 검증에서 확인합니다. 문제가 있으면 멈추고 사용자에게 inspect의 implicit 예외 처리 방법을 묻습니다 |
| UI 테스트가 CI에서 느리거나 불안정함 | 중 | 스모크 두 개로 제한하고 `waitForExistence`를 씁니다. build-test 45분 스텝 타임아웃 안에 드는지 첫 CI에서 봅니다 |
| 커스텀 스킴을 열 때 시스템 확인 알림이 뜸 | 중 | 5단계 구현 중 확인. 인터럽션 모니터로 처리합니다 |
| Renovate swift 매니저가 `Package.resolved`를 갱신하지 않아 PR이 사실상 빈 변경이 됨 | 중 | README에 보완 절차를 적습니다. 첫 PR에서 확인하고 필요하면 `postUpgradeTasks`(셀프 호스팅 전용) 대신 수동 갱신을 유지합니다 |
| Renovate가 tuist 버전을 올려 `compatibleXcodeVersions`나 `enforceExplicitDependencies` 동작이 바뀜 | 저 | 묶음 PR의 CI가 막습니다. tuist 메이저는 수동 검토로 둘지 구현 중 결정해 `packageRules`에 반영합니다 |
| inspect 오탐(조건부 import, 매크로 등)으로 CI가 막힘 | 저 | 현재는 두 종류 지적 모두 실제 원인이 확인됐습니다. 오탐이 생기면 `--only`로 좁히는 것을 사용자와 상의합니다 |
| 자리표시자 탭이 제품에 그대로 노출됨 | 중 | 템플릿 앱이라 수용합니다. `AppTab.more` doc 주석과 README에 "교체 대상"이라고 적습니다 |
| 그래프 SVG가 모듈 변경 후 오래된 채로 남음 | 중 | README "모듈 추가" 절에 갱신 안내를 넣습니다. CI 검사는 범위 밖입니다 |

## 롤백

- 단계마다 커밋이 하나라서 해당 커밋을 `git revert` 하면 됩니다.
- 1단계를 되돌리면 2단계 CI가 실패하므로 2단계도 함께 되돌립니다.
- 3~5단계는 서로 의존합니다(5 → 3, 4). 5단계만 되돌리면 앱의 스텁 경로와 빈 탭은 남지만 동작에는 영향이 없습니다.
- Renovate는 `renovate.json`을 지우거나 GitHub App을 제거하면 멈춥니다. 이미 열린 PR은 닫습니다.

## 구현 중 확인 결과 (2026-09-29)

- `tuist generate` 출력에 `enforceExplicitDependencies` deprecation 경고가 없었다. 유지 결정 그대로.
- 앱 테스트 타깃에 모듈 10개를 명시해도 중복 심볼·런타임 클래스 중복 경고가 없었다.
- `XCUIApplication.openURL:` 의 Swift 이름은 `open(_:)` 이다. 커스텀 스킴을 열 때 시스템 확인 알림이 뜨지 않았다(Xcode 27 시뮬레이터).
- uiTests → app 오탐 없음. UI 테스트 타깃을 더한 뒤에도 `tuist inspect dependencies` exit 0.
- App String Catalog(`App/Resources/Localizable.xcstrings`)가 있어 "더보기", "준비 중인 화면입니다" 항목을 더했다.
- Tuist 가 만드는 앱 스킴(`TuistApp`)의 테스트 액션에도 `TuistAppUITests` 가 자동으로 들어간다.
- 그래프 SVG 는 약 32KB. png 전환 불필요.
- Renovate 공식 검증기(`renovate-config-validator`)는 npm 패키지 다운로드가 필요해 돌리지 않았다. JSON 문법만 확인했다.
