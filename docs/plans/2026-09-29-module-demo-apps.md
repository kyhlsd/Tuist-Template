# 모듈 데모 앱 추가 (Persistence · Navigation · Auth)

## 목표

- `PersistenceDemo`, `NavigationDemo`, `AuthDemo` 앱 타깃이 생기고 각 모듈 스킴(⌘R)으로 실행된다.
- `tuist generate --no-open`이 통과하고 `./.claude/scripts/xcbuild.sh build`(워크스페이스 스킴, 데모 포함)가 통과한다.
- 각 데모는 **단위 테스트로는 확인할 수 없는 동작**을 시뮬레이터에서 조작해 볼 수 있다.
  - Persistence: 실제 디스크(SwiftData `.onDisk`, `UserDefaults`)에 쓴 값이 앱을 다시 실행해도 남는다.
  - Navigation: `Router`의 push/pop/popToRoot와 sheet·fullScreenCover 모달이 실제 화면 전환으로 보인다.
  - Auth: 실제 Keychain에 토큰을 저장·삭제하고, `AuthSession.states()` 전이(signedIn/signedOut/expired)를 화면에서 본다.
- README의 스킴 표와 모듈 구조 설명에 새 데모 3개와 **데모를 두지 않는 모듈과 그 이유**가 적힌다.

## 범위 밖

- 데모를 두지 않는 모듈: Domain, Data, Networking, Diagnostics, Tracking, FeatureFlags, Push.
  이유는 "결정 사항" D1을 따른다. 이 모듈들에는 `#Preview`도 추가하지 않는다.
- DesignSystem 컴포넌트 사용과 `mayDepend(on:)` 규칙 변경. 데모는 순수 SwiftUI로 만든다(D3).
- 스캐폴드 템플릿(`Tuist/Templates/core/DemoApp.stencil`)과 `Scripts/new-module.sh`, `Scripts/verify-templates.sh`.
- 기존 데모(DesignSystemDemo, HomeDemo) 변경. 화면 문구 리터럴은 규칙 예외로 허용했다(D4).
- 모듈 소스(`Sources/**`) 변경. 데모는 공개 API만 쓴다. 공개 API가 부족하면 구현을 멈추고 보고한다.

## 전제

### 데모 추가 방법 (모듈마다 세 곳을 같은 커밋에서 함께 바꾼다)

1. 모듈 매니페스트 `Modules/Core/<Name>/Project.swift`의 `Project.core(...)`에 `hasDemoApp: true`를 넣는다.
   `demoDependencies`는 필요할 때만 쓴다.
2. `Tuist/ProjectDescriptionHelpers/Module.swift:173-177`의 `Module.withDemoApp`에 case를 더한다.
   `// new-module.sh 가 이 줄 위에 추가한다` 주석 **위에** 넣고, 주석은 지우거나 옮기지 않는다.
3. `Modules/Core/<Name>/Demo/Sources/<Name>DemoApp.swift`에 `@main struct <Name>DemoApp: App`을 둔다.

- 1과 2가 어긋나면 `Module.validateRegistration`(`Module.swift:182-193`)이 fatalError를 낸다.
- Tuist 4.208.0은 fatalError 문구를 숨기고 실패한 `Project.swift` 경로만 보여 준다.
  문구를 보려면 오류에 찍힌 `xcrun swift ... Project.swift --tuist-dump` 명령을 그대로 실행한다.
- 데모 타깃은 `Target.demoApp(for:dependencies:)`(`Tuist/ProjectDescriptionHelpers/Project+Templates.swift:361-376`)가 만든다.
  - 이름 `<Name>Demo`, product `.app`, 번들 ID `<모듈 번들 ID>.demo`
  - 소스 `Demo/Sources/**`, 리소스 없음(따라서 `Bundle.module`도 없음)
  - Info.plist는 `.runnable`, 대상 모듈에는 자동으로 의존한다.
- 워크스페이스 스킴은 `Module.withDemoApp`을 읽어 데모 앱도 빌드한다(`Tuist/ProjectDescriptionHelpers/Scheme+Workspace.swift:26`).
  `xcbuild.sh`가 이 스킴을 쓰므로 `build` 한 번이면 데모 컴파일까지 검증된다.
  CI에는 기존 데모 2개가 이미 ClientKeys 포함으로 빌드되고 있어 추가 설정이 없다.
- `enforceExplicitDependencies`가 켜져 있다. 데모가 import하는 다른 타깃(예: `AuthTesting`)은 `demoDependencies`에 명시한다.
  자기 모듈의 `*Testing`은 `mayDepend` 규칙 없이 허용된다(`Module.swift` `validateDependencies`의 `.support` 분기).
- 매니페스트를 바꾼 뒤에는 `tuist generate --no-open`을 다시 실행한다(`xcbuild.sh`는 generate하지 않는다).

### 모듈별 사실

**Navigation** (`Modules/Core/Navigation`, `isMainActorByDefault: true`. 데모 타깃에도 MainActor 기본 격리가 적용된다)
- `Router`(`Sources/Router.swift`): `@Observable final class`로 `Routing`을 채택한다.
  - `path: NavigationPath`, `presented: (route: AnyHashable, style: PresentationStyle)?`(`private(set)`)
  - 메서드: `push(_:)`, `pop()`(빈 경로면 무시), `popToRoot()`, `present(_:style:)`(이미 떠 있으면 교체), `dismiss()`
  - 모달은 `presented`에 **기록만** 한다. 화면에 띄우는 것은 데모가 이 값을 보고 직접 한다.
- `Route`: `nonisolated protocol Route: Hashable, Sendable`. `PresentationStyle`: `.sheet`, `.fullScreenCover`.
- 기준 사례: `Modules/Features/Home/Demo/Sources/HomeDemoApp.swift`(`@State private var router = Router()` + `NavigationStack(path: $router.path)` + `.navigationDestination(for:)`)

**Persistence** (`Modules/Core/Persistence`, MainActor 기본 격리 없음)
- `LocalDatabase(location: .onDisk | .inMemory) throws(PersistenceError)`. 실패하면 `.storeUnavailable`을 던진다.
  - `.onDisk` 파일 이름은 `Persistence`로 고정되어 있다.
  - 데모는 번들 ID가 달라서 앱과 컨테이너를 공유하지 않는다.
- `SwiftDataItemCache(database:)`는 actor이며 `ItemCache`를 채택한다.
  - `load() -> [ItemCacheRecord]`, `replaceAll(with:)`(id가 겹치면 처음 것만 남김), `removeAll()`. 모두 `async throws(PersistenceError)`다.
- `ItemCacheRecord(id: String, title: String)`
- `UserDefaultsKeyValueStore(suiteName: String? = nil)`: 저장 키에 `persistence.` 접두사를 붙인다.
- `KeyValueStore` 확장 `value(for: SettingKey<V>) throws(PersistenceError) -> V`, `setValue(_:for:) throws(PersistenceError)`
- `SettingKey<Value: Codable & Sendable>(name:defaultValue:)`
- `PersistenceError` 케이스: `.storeUnavailable`, `.operationFailed`, `.decodingFailed`, `.encodingFailed`
  (구현 중 전체 케이스는 `Sources/PersistenceError.swift`에서 확인)

**Auth** (`Modules/Core/Auth`, MainActor 기본 격리 없음, Foundation·Security·os만 import)
- `AuthSession(store: any TokenStore, refresh: @escaping Refresh, logger: Logger = Logger(.disabled))`는 actor다.
  - `typealias Refresh = @Sendable (_ refreshToken: String) async throws -> AuthTokens`
  - `refresh`가 `AuthenticationError.sessionExpired`를 던지면 토큰을 지우고 `.expired`를 알린다.
  - 메서드: `currentAccessToken() async throws -> String?`, `refreshedAccessToken(rejected: String?) async throws -> String`,
    `signIn(with: AuthTokens) async throws`, `signOut() async throws`
  - `states() async -> AsyncStream<AuthSessionState>`: 첫 값은 현재 상태이고, 구독마다 따로 스트림을 만든다.
- `AuthSessionState`: `.signedIn`, `.signedOut`, `.expired`
- `AuthenticationError`: `.sessionExpired`, `.refreshFailed`
- `AuthTokens(accessToken:refreshToken:)`: `Codable`, `Sendable`
- `KeychainTokenStore(service: String)`: 실제 Keychain에 저장한다.
- `AuthTesting`에는 `InMemoryTokenStore`, `FailingTokenStore`가 있다. 구현 중 생성자 시그니처를 확인한다.

### 규약 (`.claude/rules/swift.md`)

- 강제 언래핑·`try!`·`as!`를 쓰지 않는다.
- 데모의 화면 문구는 문자열 리터럴로 쓴다(`Text("...")`, `Button("...")`). `swift.md` "하드코딩" 절의 데모 예외다(D4).
  데모 타깃에는 `Bundle.module`도 번역 카탈로그도 없다.
- 상수(Keychain service 이름, SettingKey 이름, 샘플 개수 등)는 `private enum` 네임스페이스에, UI 수치는 파일 하단 `private enum Layout`에 모은다.
- 타입당 한 파일, 파일명은 타입명과 같게 한다.
- UI 상태 타입은 `@MainActor @Observable`로 둔다. `@unchecked Sendable`은 쓰지 않는다.
- 에러는 삼키지 않는다. 데모는 받은 에러를 화면의 상태 문구로 보여 준다.
- 싱글턴을 새로 만들지 않고 생성자로 주입한다. 조립은 `@main App`에서 한다.
- `PreviewProvider`는 Xcode 27에서 deprecated다. 프리뷰가 필요하면 `#Preview`만 쓴다(필수 아님).

### 알려진 함정

- Keychain: 시뮬레이터에서 서명 없이 실행하면 `errSecMissingEntitlement`(-34018)가 날 수 있다(구현 중 확인).
  나면 저장소 선택기로 InMemory로 바꿔 쓰고, 오류 문구를 화면에 보여 준다. 엔타이틀먼트는 추가하지 않는다.
- `Router.presented`는 사용자가 sheet를 아래로 쓸어 닫아도 스스로 비워지지 않는다. 모달 바인딩의 `set`에서 `router.dismiss()`를 불러야 한다.
- `AuthSession.states()` 구독은 뷰가 사라질 때 끊어야 한다. `.task { for await ... }`로 구독해 뷰 수명에 묶는다.
- `refresh` 클로저는 `@Sendable`이다. 데모의 "서버 응답 모드" 같은 가변 상태는 actor에 두고 클로저가 그 actor를 캡처한다(`Mutex`는 iOS 18부터라 쓰지 않는다).

## 결정 사항

| # | 결정 | 선택 | 이유 |
|---|---|---|---|
| D1 | 데모 대상 | Persistence, Navigation, Auth | 기준은 "데모로만 확인할 수 있는 동작이 있는가"다. 셋은 실제 디스크, 실제 화면 전환, 실제 Keychain을 쓴다. 나머지 모듈은 이렇다. Domain·Data는 프로토콜·구현이라 화면이 없고, Data를 띄우면 앱을 다시 만드는 셈이다. Networking은 서버가 필요하고 미들웨어는 테스트가 덮는다. Diagnostics·Tracking은 Console 로그 한 줄이 전부다. FeatureFlags는 기본값 제공자가 15줄이라 토글 화면이 결국 테스트 스텁을 조작한다. Push는 파싱 함수 2개다. (사용자 확인) |
| D2 | 방식 | 기존 `hasDemoApp` + `Target.demoApp` (플랫폼 조사 A안) | 저장소에 인프라가 이미 있다. `#Preview`만 쓰는 방식(B)은 실제 런타임 흐름을 확인할 수 없고, 카탈로그 통합 앱(C)은 모듈 격리를 깬다 |
| D3 | UI 구성 | 순수 SwiftUI(List/Form/Button/Picker), DesignSystem 미사용 | `mayDepend`는 실제 앱 의존 방향을 기준으로 잡혀 있어 데모 때문에 넓히지 않는다 (사용자 확인) |
| D4 | 데모 화면 문구 | 문자열 리터럴 허용. `.claude/rules/swift.md` "하드코딩" 절에 데모 예외를 명시했다(계획 작성 시 반영, 1단계 커밋에 포함) | 데모는 배포하지 않고 번역 카탈로그도 없어 `String(localized:)`로 감싸도 결과가 같다. 기존 DesignSystemDemo(약 150곳)를 고치는 diff 비용만 생긴다. 키·식별자 상수와 `Layout` 수치 규칙은 그대로 적용한다 (사용자 확인) |
| D5 | Auth 저장소 | 실제 `KeychainTokenStore`가 기본값. 화면의 Picker로 `InMemoryTokenStore`·`FailingTokenStore`(AuthTesting)로 바꾼다 | 데모의 핵심 가치가 실제 Keychain이다. Failing은 저장 실패 경로를 보여 준다. 저장소를 바꾸면 `AuthSession`을 새로 만든다 |
| D6 | Auth refresh | 데모 내부 actor가 모드(성공 / `sessionExpired` / `refreshFailed`)에 따라 응답한다 | 서버 없이 갱신·만료 전이를 재현한다 |
| D7 | Persistence 저장 위치 | `.onDisk`, 실패하면 `.inMemory`로 폴백하고 폴백 사실을 화면에 표시 | 재실행 후에도 값이 남는지 보는 게 목적이다. 폴백은 앱 조립 방식과 같다 |
| D8 | 커밋 단위 | 데모 하나당 커밋 1개 + 문서 커밋 1개 | 각 단계가 독립적으로 generate와 빌드를 통과한다 |

## 변경 계획

작업 브랜치에서 한다(예: `feat/module-demo-apps`). `main`에 직접 커밋하지 않는다.
단계마다 `tuist generate --no-open` → `./.claude/scripts/xcbuild.sh build` → 데모 실행 확인 순으로 진행한다.

### 1. NavigationDemo

- 파일:
  - `Modules/Core/Navigation/Project.swift`: `hasDemoApp: true`를 넣는다. 파일 주석에 "NavigationDemo는 `Router`의 스택·모달 동작을 조작해 보는 앱이다"를 더한다.
  - `Tuist/ProjectDescriptionHelpers/Module.swift`: `withDemoApp`에 `.navigation`을 더한다.
  - `Modules/Core/Navigation/Demo/Sources/NavigationDemoApp.swift`: `@main`. `@State private var router = Router()`를 두고 루트 뷰에 넘긴다.
  - `.../Demo/Sources/DemoRoute.swift`: `enum DemoRoute: Route { case page(depth: Int); case modal }`
  - `.../Demo/Sources/NavigationDemoRootView.swift`: 루트 화면.
    - `NavigationStack(path: $router.path)`
    - `.navigationDestination(for: DemoRoute.self)`
    - `.sheet`·`.fullScreenCover`는 `router.presented`에서 만든 `Binding<Bool>`으로 띄운다. `set(false)` 시 `router.dismiss()`를 부른다.
  - `.../Demo/Sources/DemoPageView.swift`: 각 단계 화면.
    - 현재 깊이와 `router.path.count`를 표시한다.
    - 버튼: 다음 push, pop, popToRoot, sheet present, fullScreenCover present
  - `.../Demo/Sources/DemoModalView.swift`: 모달 안에서 `router.dismiss()`를 부르고, 모달 교체(`present` 재호출)를 확인하는 버튼을 둔다.
- 변경: 위와 같다. `demoDependencies`는 없다.
  - 이 커밋에 `.claude/rules/swift.md`의 데모 문자열 예외(작업 트리에 이미 반영됨)를 함께 넣는다.
- 검증:
  - generate와 build가 통과한다.
  - 시뮬레이터에서 `NavigationDemo`를 실행한다(UDID는 `xcbuild.sh udid`). 확인할 것:
    - push 3회 후 popToRoot하면 루트로 돌아온다.
    - sheet를 쓸어 닫은 뒤 다시 present하면 뜬다(`presented`가 비워졌는지 확인).
    - fullScreenCover의 닫기 버튼이 동작한다.
    - sheet 안에서 "fullScreenCover 로 교체"를 누르면 sheet가 닫히고 fullScreenCover가 뜬다(`presented`가 남은 채 빈 화면이 되지 않는다).

### 2. PersistenceDemo

- 파일:
  - `Modules/Core/Persistence/Project.swift`: `hasDemoApp: true`를 넣고 파일 주석을 갱신한다.
  - `Module.swift`: `withDemoApp`에 `.core("Persistence")`를 더한다.
  - `Modules/Core/Persistence/Demo/Sources/PersistenceDemoApp.swift`: `@main`. 조립을 맡는다.
    - `LocalDatabase(location: .onDisk)`를 연다. 실패하면 `.inMemory`로 폴백하고 폴백 여부를 모델에 넘긴다.
    - `.inMemory`마저 실패하면 에러 화면을 보여 준다(강제 언래핑 금지).
    - `SwiftDataItemCache`와 `UserDefaultsKeyValueStore()`를 만든다.
  - `.../Demo/Sources/PersistenceDemoModel.swift`: `@MainActor @Observable`. `any ItemCache`와 `any KeyValueStore`를 주입받는다.
    - 상태: `records`, `launchCount`, `lastError: PersistenceError?`, `isInMemoryFallback`
    - 동작: `load()`, `replaceWithSamples()`(샘플 N개, id 중복 1개 포함 → 중복 제거 확인), `removeAll()`,
      `incrementLaunchCount()`(시작 시 1회, `SettingKey<Int>`), `resetLaunchCount()`(`removeValue(forKey:)`)
  - `.../Demo/Sources/PersistenceDemoView.swift`: 위 모델을 쓰는 `Form` 화면.
    - 섹션: 저장 위치(onDisk/폴백), 실행 횟수, 캐시 항목 목록, 마지막 에러
- 변경: 위와 같다. `demoDependencies`는 없다(자기 모듈에 자동으로 의존한다).
- 검증:
  - generate와 build가 통과한다.
  - 샘플로 교체한 뒤 앱을 종료하고 다시 실행한다. 확인할 것:
    - 항목이 그대로 남는다.
    - 실행 횟수가 1 늘어난다.
    - 중복 id가 한 번만 나타난다.
    - 비우기 후 재실행하면 빈 목록이다.

### 3. AuthDemo

- 파일:
  - `Modules/Core/Auth/Project.swift`: `hasDemoApp: true`, `demoDependencies: [.testing(.auth)]`를 넣는다. 의존 옆에 이유 주석을 달고, 파일 주석을 갱신한다.
  - `Module.swift`: `withDemoApp`에 `.auth`를 더한다.
  - `Modules/Core/Auth/Demo/Sources/AuthDemoApp.swift`: `@main`. 모델을 만든다.
  - `.../Demo/Sources/DemoRefreshServer.swift`: `actor`. 가짜 서버 역할을 한다.
    - `mode`: 성공 / 만료 / 실패
    - `refresh(_ refreshToken:) async throws -> AuthTokens`: 성공이면 새 토큰(UUID 기반)을 돌려준다. 나머지는 각각 `AuthenticationError.sessionExpired`와 `.refreshFailed`를 던진다.
  - `.../Demo/Sources/DemoTokenStoreKind.swift`: `enum`(keychain / inMemory / failing)과 `makeStore() -> any TokenStore`.
    Keychain service 이름은 이 파일의 `private enum`에 둔다.
  - `.../Demo/Sources/AuthDemoModel.swift`: `@MainActor @Observable`.
    - 상태: 저장소 종류, 서버 모드, `state: AuthSessionState?`, 마지막으로 읽은 access token, 마지막 에러 문구
    - 저장소 종류가 바뀌면 `AuthSession`을 새로 만든다. 세션의 `refresh`에는 `DemoRefreshServer`의 메서드를 넘기고, `logger`에는 `Logger(subsystem: 번들 ID, category:)`를 넘긴다.
    - 동작: `signIn()`, `signOut()`, `readToken()`, `refresh()`(`refreshedAccessToken(rejected: 현재 토큰)`), `observeStates()`
  - `.../Demo/Sources/AuthDemoView.swift`: `Form` 화면.
    - 컨트롤: 저장소 Picker, 서버 모드 Picker, 상태·토큰 표시, 동작 버튼, 에러 문구
    - `.task(id: 세션 식별자)`에서 `states()`를 구독한다. 저장소를 바꾸면 구독도 다시 한다.
- 변경: 위와 같다.
- 검증:
  - generate와 build가 통과한다. `AuthTesting` 누락 시 generate가 멈추므로, generate 통과가 곧 의존 명시 확인이다.
  - 시뮬레이터에서 확인할 것:
    - Keychain 저장소로 로그인한 뒤 앱을 재실행하면 첫 상태가 `.signedIn`이다.
    - 서버 모드 "만료"에서 갱신하면 `.expired`가 되고 토큰이 비워진다.
    - Failing 저장소에서 로그인하면 에러 문구가 뜬다.
    - Keychain이 -34018로 실패하면 결과를 보고하고 D5 폴백(InMemory)으로 확인한다.

### 4. 문서

- 파일: `README.md`
  - 49-52행 부근 모듈 구조: Navigation·Persistence·Auth 줄에 `(+ <Name>Demo: ...)`를 표기한다.
  - 186-187행 스킴 표: `Navigation`, `Persistence`, `Auth` 행을 추가한다.
  - 스킴 표 아래 한 단락: 데모를 두지 않는 모듈과 이유를 적는다(D1을 요약).
  - 421-422행 문제 해결: 데모 이름을 나열하지 말고 "모든 데모 앱(`Module.withDemoApp`)"으로 일반화한다.
- 검증: `Scripts/module-graph.sh`를 실행해 README 그래프 출력이 바뀌는지 확인한다. 바뀌면 갱신한다(데모를 그래프에 표시하는지는 구현 중 확인).

## 테스트 전략

- 새 단위 테스트는 없다. 데모 타깃은 테스트 타깃이 아니며, 데모가 쓰는 동작은 이미 각 모듈 테스트가 고정하고 있다.
  (RouterTests, SwiftDataItemCacheTests, KeyValueStoreCodableTests, AuthSessionTests, AuthSessionTransitionRaceTests)
- 회귀 확인: 마지막 단계 후 `./.claude/scripts/xcbuild.sh test`로 전체 테스트가 그대로 통과하는지 본다. 수정할 기존 테스트는 없다.
- 동작 확인: 각 단계의 "검증"에 적은 시나리오를 시뮬레이터에서 실행하고, 스크린샷 한 장씩으로 확인한다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| `hasDemoApp`과 `withDemoApp` 불일치로 generate가 문구 없이 멈춤 | 중 | 세 곳을 같은 커밋에서 바꾼다. 멈추면 `--tuist-dump` 명령으로 문구를 확인한다 |
| 시뮬레이터 Keychain -34018 | 중 | D5 폴백으로 확인하고 결과를 보고한다. 엔타이틀먼트 추가는 이번 범위 밖이다 |
| 데모에 필요한 공개 API 부족(예: AuthTesting 생성자가 internal) | 낮음 | 모듈 소스를 고치지 말고 멈춰서 보고한다 |
| 워크스페이스 빌드 시간 증가 | 확정(소폭) | 데모 3개는 작은 SwiftUI 앱이라 감수한다 |
| Navigation 데모에 MainActor 기본 격리가 적용되어 `nonisolated` 요구와 충돌 | 낮음 | `DemoRoute`는 `Route`가 `nonisolated`라 값 타입으로만 둔다. 컴파일 오류가 나면 해당 타입에 `nonisolated`를 명시한다 |
| SwiftLint·swiftformat 위반(파일 길이 등) | 중 | 커밋 전에 린트를 돌리고 키·식별자 상수는 `private enum`으로 뺀다 |

## 롤백

단계마다 커밋이 독립적이다. 데모 하나를 되돌리려면 그 커밋을 `git revert`하고 `tuist generate`를 다시 실행한다.
세 곳(`Project.swift`의 `hasDemoApp`, `Module.withDemoApp`, `Demo/` 폴더)이 한 커밋에 묶여 있으므로 revert 뒤에도 등록이 어긋나지 않는다.
