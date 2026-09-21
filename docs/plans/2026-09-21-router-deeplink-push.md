# 라우터 재설계 (딥링크·푸시 지원)

## 목표

- 앱 수준 라우터 하나(`AppRouter`)가 **선택된 탭, 탭별 스택(`[AppRoute]`), 모달 하나**를 소유한다.
  뷰는 이 상태를 바인딩만 한다.
- 뷰모델은 지금처럼 `Routing` 프로토콜만 보고 `push` / `pop` / `popToRoot` / `present` / `dismiss`를 요청한다.
  push 할 수 있는 값은 `Route` 프로토콜을 따르는 타입뿐이다(컴파일 타임에 막힘).
- `tuistapp://home/items/42`를 열면 앱이 실행 중이든(웜) 종료 상태든(콜드) Home 탭으로 전환되고
  스택이 `[.home(.detail(id: "42"))]`로 교체된다.
- 푸시 알림 payload의 `link` 문자열이 위 URL이면, 알림을 탭했을 때 같은 결과가 나온다(웜/콜드 모두).
- 파싱할 수 없는 URL·payload는 아무 일도 일으키지 않는다(크래시·빈 화면 없음).
- 모든 링크는 `AppRouter.handle(_ url: URL)` 한 입구로 들어온다. 나중에 Universal Links나
  deferred deep link SDK를 붙일 때 호출부 한 줄만 추가하면 된다.
- 인증이 필요한 목적지가 생겼을 때 넣을 자리(`DeepLinkGate`, 보류 후 재생)가 있고,
  지금은 모든 링크를 허용한다.
- `./.claude/scripts/xcbuild.sh test` 통과.

## 범위 밖

- **Universal Links:** Associated Domains 엔타이틀먼트, AASA 파일, 도메인 준비. 파서는 스킴과 무관하게 동작하도록만 만든다.
- **Deferred deep link:** 설치 후 원래 화면으로 보내는 기능과 SDK(Branch, AppsFlyer 등) 도입.
- **푸시 등록:** 알림 권한 요청, `registerForRemoteNotifications`, APNs 토큰 서버 전송, `aps-environment` 엔타이틀먼트.
  이번에는 "탭된 알림을 라우팅"만 한다.
- **경로 복원:** `@SceneStorage` 등.
- **중첩 모달:** 모달 위의 모달. 모달은 한 단계만 지원한다.
- **모달 목적지로 가는 딥링크:** 딥링크는 탭과 스택만 지정한다. `DeepLink`에 필드를 추가해 확장할 수 있는 형태로만 둔다.
- **Route → URL 역변환:** 공유 링크 생성 등.
- **다른 피처 추가, 탭 추가:** `AppTab`은 `.home` 하나로 유지한다.

## 전제

### 최소 지원 버전·환경
- iOS 17.0, Swift 6 언어 모드(`Tuist/ProjectDescriptionHelpers/AppConstants.swift:23`). 외부 SPM 의존성 0개(`Tuist/Package.swift`). 이번에도 추가하지 않는다.
- Navigation 모듈은 `isMainActorByDefault: true`(`Modules/Core/Navigation/Project.swift:16`)라서 `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`이다.
  이 설정은 모듈의 구현·테스트·데모 타깃 전부에 적용된다(`Tuist/ProjectDescriptionHelpers/Settings+Common.swift:49`).
- App 타깃은 `.common` 설정이라 기본 격리가 없다(`Project+Templates.swift:167`). App의 UI 타입에는 `@MainActor`를 명시한다.
- 모듈 의존 방향: `App → Feature → FeatureInterface → Domain`(`Tuist/ProjectDescriptionHelpers/Module.swift:15-24`).
  Navigation은 피처를 모르고, Route → 화면 매핑은 App만 한다.

### 현재 코드 (변경 지점)
| 파일:줄 | 현재 | 이번 변경 |
|---|---|---|
| `Modules/Core/Navigation/Sources/Routing.swift:14` | `push(_ route: some Hashable)`, `pop`, `popToRoot` | `some Route`로 좁히고 `present`/`dismiss` 추가 |
| `Modules/Core/Navigation/Sources/Router.swift:14` | 탭 하나의 `NavigationPath` 래퍼. 주석에 "모달은 각 화면이 자기 상태로 띄운다" | 앱에서는 더 이상 쓰지 않음. **데모 앱·프리뷰용 단독 구현**으로 역할 변경, `present`/`dismiss` 구현 |
| `Modules/Core/Navigation/Testing/Sources/SpyRouter.swift:15` | 3개 API 기록 | 새 API 기록 추가 |
| `Modules/Core/Navigation/Tests/RouterTests.swift:41` | `private enum TestRoute: Hashable` | `Route` 채택으로 수정, present/dismiss 테스트 추가 |
| `Modules/Features/Home/Interface/Sources/HomeRoute.swift:15` | `enum HomeRoute: Hashable, Sendable { case detail(id: Item.ID) }` | `Route` 채택, 경로 파싱 init 추가 |
| `Modules/Features/Home/Project.swift:13` | `interfaceDependencies: [.module(.domain)]` | `.module(.navigation)` 추가 |
| `Modules/Features/Home/Sources/HomeViewModel.swift:28,45` | `any Routing` 주입, `router.push(HomeRoute.detail(id:))` | 변경 없음(컴파일 확인만) |
| `Modules/Features/Home/Demo/Sources/HomeDemoApp.swift:21-29` | `Router()` + `NavigationStack(path: $router.path)` | `Router` API 변경에 맞춰 컴파일되게 유지 |
| `App/Sources/TuistAppApp.swift:10` | `WindowGroup { RootView(container:) }`만 있음 | `@UIApplicationDelegateAdaptor`, `onOpenURL` |
| `App/Sources/Navigation/RootView.swift:13` | `@State private var selectedTab` | `AppRouter.selectedTab` 바인딩, 모달 표시 |
| `App/Sources/Navigation/TabRootView.swift:17` | 탭마다 `@State private var router = Router()` | `AppRouter`의 해당 탭 스택 바인딩과 탭별 `Routing` 어댑터 |
| `App/Sources/Navigation/View+AppDestinations.swift:15` | `navigationDestination(for: HomeRoute.self)` | `navigationDestination(for: AppRoute.self)` |
| `App/Sources/DI/AppContainer+Home.swift:13,19` | `makeHomeView(router:)`, `makeView(for: HomeRoute)` | 유지. `AppRoute`를 화면으로 바꾸는 진입점 추가 |
| `Tuist/ProjectDescriptionHelpers/Settings+Common.swift:62` | `InfoPlist.runnable(displayName:)`. 앱과 데모 앱이 공유 | URL 스킴 인자 추가. **데모 앱은 스킴을 등록하지 않는다** |
| `Tuist/ProjectDescriptionHelpers/Project+Templates.swift:175` | 앱 타깃 `infoPlist: .runnable()` | 스킴 전달 |
| `App/Tests/TuistAppTests.swift` | Swift Testing, `@testable import TuistApp` | 새 테스트 파일은 같은 타깃에 추가 |

- `Item.ID`는 `String`이다(`Modules/Core/Domain/Sources/Item.swift:12`). URL 세그먼트를 변환 없이 그대로 쓸 수 있다.
- 딥링크·푸시 관련 코드와 설정(`onOpenURL`, AppDelegate, `UNUserNotificationCenter`, `CFBundleURLTypes`, entitlements)은 저장소에 **전혀 없다**.

### 쓰기로 한 API (모두 iOS 17 이하에서 사용 가능, 폴백 불필요)
| 심볼 | 도입 | 비고 |
|---|---|---|
| `NavigationStack(path:)` + `Binding<[AppRoute]>` | iOS 16 | 타입이 정해진 배열 경로 |
| `navigationDestination(for:destination:)` | iOS 16 | 스택 루트에 한 번만 붙인다 |
| `sheet(item:)` / `fullScreenCover(item:)` | iOS 13 / 14 | 항목이 `Identifiable`이어야 함 |
| `TabView(selection:)` + `.tag` | iOS 13 | 새 `Tab` API는 iOS 18부터라 쓰지 않는다 |
| `onOpenURL(perform:)` | iOS 14 | 커스텀 스킴과 Universal Link를 모두 URL로 받는다 |
| `UIApplicationDelegateAdaptor` | iOS 14 | `@MainActor` |
| `UNUserNotificationCenter.current().delegate` | iOS 10 | **`application(_:didFinishLaunchingWithOptions:)`가 반환되기 전에** 설정해야 콜드 스타트 탭도 `didReceive`로 온다 |
| `userNotificationCenter(_:didReceive:) async` | iOS 10 | 알림 탭 처리 |
| `userNotificationCenter(_:willPresent:) async -> UNNotificationPresentationOptions` | iOS 10 | 포그라운드에서도 배너를 보여야 탭할 수 있다 |
| `@Observable` | iOS 17 | `AppRouter` 상태 |

출처: https://developer.apple.com/documentation/swiftui/navigationstack ,
https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:) ,
https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/delegate ,
https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor

### 권한 키·설정
- `Info.plist`의 `CFBundleURLTypes`에 `CFBundleURLSchemes = [tuistapp]`, `CFBundleURLName = <번들 ID>`를 등록한다. Tuist 매니페스트에서 생성하고, 생성된 `.xcodeproj`나 plist는 편집하지 않는다.
- 알림 탭 라우팅 자체에는 권한 키나 엔타이틀먼트가 필요 없다. 권한 요청은 범위 밖이다.

### 알려진 함정
- **`launchOptions[.remoteNotification]`:** iOS 26부터 deprecated이므로 쓰지 않는다. 콜드 스타트도 `didReceive` 하나로 통일한다.
- **`didReceive` 격리:** async `didReceive`를 nonisolated로 두면 완료 처리가 메인 밖에서 불려 `dispatch_assert_queue` 크래시가 난다(https://developer.apple.com/forums/thread/796407).
  - 1순위는 격리 적합성 `extension AppDelegate: @MainActor UNUserNotificationCenterDelegate`(SE-0470)이다.
  - 컴파일러가 거부하면 폴백으로 간다. `nonisolated` 메서드에서 `String?`(링크)만 뽑은 뒤 `await MainActor.run`으로 넘긴다.
  - 어느 쪽이 되는지는 **구현 중 확인**한다.
- **푸시가 뷰보다 먼저 오는 경우:** 콜드 스타트에서 푸시 콜백은 뷰 트리가 생기기 전에 올 수 있다.
  - 그래서 `AppRouter`는 뷰가 아니라 **AppDelegate가 소유**한다. AppDelegate는 `didFinishLaunching`보다 먼저 생성된다.
  - 루트 뷰가 나타나기 전 링크는 보류했다가 재생한다.
- **`onOpenURL` 호출 시점:** 콜드 스타트에서 첫 `onAppear` 전인지 후인지는 공식 문서에 없다. 보류·재생 구조가 두 경우를 모두 처리하므로 순서에 의존하지 않는다.
- **한 번에 여러 단계 이동:** 탭 전환, 모달 닫기, 스택 교체를 같은 틱에 하면 애니메이션이 꼬일 수 있다. 공식 문서로 확인하지 못한 경험칙이며 실제 동작은 **구현 중 확인**한다.
- **`navigationDestination` 등록 위치:** 스택 루트에 한 번만 붙인다. 같은 타입을 중첩 등록하면 경고가 나고 동작이 불확정이다.
- **MainActor 기본 격리 모듈의 프로토콜:** Navigation 모듈에 선언하는 `Route` 프로토콜과 `PresentationStyle`은 순수 값 타입용이다. 파서 등 비격리 문맥에서도 써야 하므로 `nonisolated`로 선언한다. 문법·효과는 **구현 중 확인**한다.
- **딥링크 입력은 신뢰하지 않는다:** 파싱 실패는 무시하고 `preconditionFailure`를 쓰지 않는다.

### 조사 간 충돌과 해소
1. **Route 모델:** 플랫폼 조사는 "모든 피처를 아는 공통 `Route` enum 하나"를 권했다. 저장소는 Route를 피처 Interface마다 따로 두고 Navigation은 피처를 모르는 구조다.
   - 해소: 피처 Route는 Interface에 그대로 두고, 모든 피처를 아는 App 타깃의 `enum AppRoute`가 감싼다.
2. **`[AppRoute]` 배열과 `Routing.push`:** 배열 원소 타입은 App에만 있지만 `push`는 피처가 부른다. 피처는 `AppRoute`를 모르므로 컴파일 타임에 직접 변환할 수 없다.
   - 해소: Navigation에 마커 프로토콜 `Route`를 두어 push 가능한 값을 컴파일 타임에 제한한다.
   - `some Route` → `AppRoute` 변환은 App의 `AppRoute.init?(_:)` **한 곳**에서 런타임 캐스팅으로 한다. 테스트로 모든 피처 Route가 변환되는지 고정한다.
   - 대가로 `FeatureInterface → Navigation` 의존이 새로 생긴다. `Module.swift`의 도식을 갱신한다.
3. **모달 소유권:** 현재 `Router.swift:12` 주석은 "모달은 각 화면이 자기 상태로 띄운다"이다. 이 방식이면 딥링크로 모달을 제어하거나 닫을 수 없다.
   - 해소: 라우터가 모달 한 단계를 소유한다. 각 화면이 로컬 상태로 띄우는 확인 다이얼로그·알럿은 계속 허용한다. 문서에 경계를 적는다.

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 서드파티 | 사용하지 않음 | 의존성 0개 원칙. 시스템 API로 충분하다(플랫폼 조사 A안) |
| 경로 표현 | 탭별 `[AppRoute]` | 사용자 결정. 내용을 검사·테스트할 수 있다 |
| push 가능한 값 | Navigation의 `Route` 마커 프로토콜(`Hashable & Sendable`) | 템플릿이므로 최소 수정보다 올바른 구조(사용자 지시). 아무 `Hashable`이나 push하는 실수를 막는다 |
| `Route` → `AppRoute` 변환 | App의 `AppRoute.init?(_ route: some Route)` 한 곳에서 캐스팅. 실패 시 `assertionFailure` 후 무시 | 피처가 `AppRoute`를 알 수 없는 구조상 불가피하다. 판정을 한 곳에 모아 테스트한다 |
| 라우터 소유자 | `AppDelegate`가 `AppRouter`를 만들고 `TuistAppApp`이 `appDelegate.router`를 뷰에 전달 | 푸시 콜백이 뷰보다 먼저 올 수 있다. 싱글턴을 만들지 않는다 |
| 뷰모델이 보는 창구 | `Routing` 유지. 탭·모달 문맥별로 `AppRouter`가 만든 어댑터(`ScopedRouter`)를 주입 | 뷰모델은 자기가 어느 탭·모달에 있는지 몰라도 된다. `SpyRouter` 테스트 방식을 유지한다 |
| 모달 | `AppRouter.presented: PresentedRoute?` 한 단계. 모달 안에 자기 `NavigationStack`과 `[AppRoute]` 경로를 둔다 | 딥링크·푸시로 모달을 닫고 이동할 수 있어야 한다. 중첩은 범위 밖 |
| 모달 방식 | `PresentationStyle { case sheet, fullScreenCover }`(Navigation)를 `present` 인자로 받음 | 뷰모델이 방식을 고른다. 매핑 테이블을 둘 필요가 없다 |
| 딥링크 결과 모델 | `struct DeepLink: Equatable { let tab: AppTab; let path: [AppRoute] }` | 탭과 스택만 지정한다. 모달 필드는 나중에 추가 |
| 딥링크 적용 방식 | 모달 닫기 → 탭 전환 → 해당 탭 스택 **교체** | 결과가 예측 가능하다. 기존 스택에 덧붙이면 링크마다 결과가 달라진다 |
| URL → 세그먼트 규칙 | 커스텀 스킴이면 `[host] + pathComponents`, `http(s)`면 `pathComponents`(`/` 제외) | 두 형식이 같은 세그먼트 배열이 된다. Universal Links를 붙일 때 파서를 고치지 않는다 |
| 파싱 위치 | 첫 세그먼트 → 탭·피처는 App의 `DeepLinkParser`. 나머지 → Route는 각 Interface의 `init?(pathComponents:)` | URL 형식은 그 피처가 소유한다. 파서 프로토콜은 두지 않는다(App이 구체 타입을 직접 호출하므로 불필요) |
| 푸시 payload | `userInfo["link"]`의 URL 문자열을 `handle(url)`로 넘긴다 | 딥링크와 파서를 공유한다. **서버와 키 이름 합의 필요** |
| 포그라운드 알림 | `willPresent`에서 `[.banner, .list, .sound]` 반환 | 앱을 사용하는 중에도 알림을 탭해 이동할 수 있게 한다 |
| 보류·재생 | `pending: DeepLink?`(마지막 것만 유지). 준비 전이거나 게이트가 거부하면 보류. `markReady()`와 `resumePending()`에서 재생 | 콜드 스타트와 추후 인증을 같은 구조로 처리한다 |
| 인증 확장 지점 | `protocol DeepLinkGate { func canOpen(_ link: DeepLink) -> Bool }`를 `AppRouter` 생성자로 주입. 지금은 `AllowAllDeepLinkGate` | 사용자 요구(인증 목적지를 나중에 추가). 로그인 후 `resumePending()`을 호출하면 된다 |
| URL 스킴 값 | `tuistapp`. `AppConstants.urlScheme`에 둔다 | 템플릿 기본값. 앱마다 바꾼다. 앱 코드는 스킴을 비교하지 않는다 |
| 기존 `Router`(Navigation) | 삭제하지 않고 데모·프리뷰용 단독 구현으로 유지 | 피처 데모 앱은 App의 `AppRouter`를 쓸 수 없다 |

## 변경 계획

작업 브랜치 `feat/router-deeplink`에서 한다(`main` 직접 커밋 금지).

### 1. Navigation: `Route` 프로토콜과 `Routing` API 확장
- 파일:
  - `Modules/Core/Navigation/Sources/Route.swift`(신규): `nonisolated public protocol Route: Hashable, Sendable {}`. SwiftUI를 import하지 않는다.
  - `Modules/Core/Navigation/Sources/PresentationStyle.swift`(신규): `nonisolated public enum PresentationStyle: Hashable, Sendable { case sheet, fullScreenCover }`
  - `Modules/Core/Navigation/Sources/Routing.swift`: `push(_ route: some Route)`, `pop()`, `popToRoot()`, `present(_ route: some Route, style: PresentationStyle)`, `dismiss()`. 문서 주석에 모달 경계(라우터 소유 모달과 화면 로컬 알럿)를 적는다.
  - `Modules/Core/Navigation/Sources/Router.swift`:
    - 역할을 "데모 앱·프리뷰용 단독 구현"으로 바꾸고 주석을 갱신한다.
    - `present`/`dismiss`는 `public private(set) var presented: (route: AnyHashable, style: PresentationStyle)?` 형태로 기록한다.
    - 데모가 이 값을 써서 모달을 띄울 수 있게 `Identifiable` 래퍼를 두는 것까지는 하지 않고, 기록만 한다. 구체 형태는 구현 중 결정한다.
  - `Modules/Core/Navigation/Testing/Sources/SpyRouter.swift`: `pushedRoutes: [AnyHashable]` 유지. `presentedRoutes: [(AnyHashable, PresentationStyle)]`와 `dismissCount`를 추가한다. 튜플이 불편하면 작은 기록 구조체로 바꾼다.
  - `Modules/Features/Home/Interface/Sources/HomeRoute.swift`: `: Route`를 채택한다(`Hashable, Sendable`은 상속으로 대체).
  - `Modules/Features/Home/Project.swift:13`: `interfaceDependencies`에 `.module(.navigation)`을 추가한다.
  - `Tuist/ProjectDescriptionHelpers/Module.swift:15-30`: 도식에 `FeatureInterface ──→ Navigation (Route 프로토콜)`을 추가하고 `.navigation` 설명을 갱신한다.
  - `Modules/Core/Navigation/Project.swift:9` 주석 갱신.
- 변경: 위와 같다. `HomeViewModel`, `HomeDemoApp`은 컴파일만 되게 한다.
- 검증: `tuist generate` 후 `./.claude/scripts/xcbuild.sh build`와 `test` 통과(데모 타깃 포함). `RouterTests`, `HomeViewModelTests` 통과.

### 2. HomeInterface: 경로 세그먼트 → `HomeRoute`
- 파일: `Modules/Features/Home/Interface/Sources/HomeRoute+PathComponents.swift`(신규), `Modules/Features/Home/Tests/HomeRoutePathComponentsTests.swift`(신규)
- 변경:
  - `public init?(pathComponents: [String])`: `["items", id]`이고 `id`가 비어 있지 않으면 `.detail(id:)`, 나머지는 `nil`.
  - 세그먼트 리터럴은 `private enum PathComponent { static let items = "items" }`에 둔다.
  - 세그먼트 배열에는 이 피처 몫만 들어온다(탭 세그먼트 `home`은 App이 이미 소비).
- 검증: 새 테스트 통과.

### 3. App: `AppRoute`, `DeepLink`, `DeepLinkParser`
- 파일(모두 `App/Sources/Navigation/`):
  - `AppRoute.swift`
    - `enum AppRoute: Hashable { case home(HomeRoute) }`와 `init?(_ route: some Route)`. (리뷰 R1-9: 쓰이지 않는 `Identifiable` 제거)
    - 캐스팅 실패 시 `nil`을 반환한다. `assertionFailure`는 호출부(`ScopedRouter`)에서 한다. 파서 테스트에서 실패 분기를 검증할 수 있게 하기 위해서다.
  - `DeepLink.swift`: `struct DeepLink: Equatable { let tab: AppTab; let path: [AppRoute] }`
  - `DeepLinkParser.swift`
    - `struct DeepLinkParser { func parse(_ url: URL) -> DeepLink? }`
    - 세그먼트 추출 규칙은 "결정 사항"과 같다. 첫 세그먼트로 `AppTab`을 고르고, 나머지가 비었으면 `path: []`(탭 루트), 아니면 해당 피처의 `init?(pathComponents:)`를 호출한다.
    - 탭 세그먼트 문자열은 `private enum`에 둔다. 매핑은 `AppTab` 쪽에 둘 수도 있으니 구현 중 판단한다.
  - `App/Tests/AppRouteTests.swift`, `App/Tests/DeepLinkParserTests.swift`(신규)
- 검증: `xcbuild.sh test` 통과. App 테스트 타깃에서 `HomeInterface`/`Navigation` import가 되는지 **구현 중 확인**한다. 안 되면 `App/Project.swift`에 `testDependencies`를 추가한다.

### 4. App: `AppRouter`, `ScopedRouter`, `DeepLinkGate`
- 파일(`App/Sources/Navigation/`):
  - `AppRouter.swift`: `@MainActor @Observable final class AppRouter`
    - 상태: `var selectedTab: AppTab`, `private(set) var paths: [AppTab: [AppRoute]]`, `var presented: PresentedRoute?`, `@ObservationIgnored private var pending: DeepLink?`, `private var isReady = false`
    - `init(gate: any DeepLinkGate)`
    - 바인딩용: `func path(for tab: AppTab) -> Binding<[AppRoute]>` 또는 `subscript`. `@Bindable`과의 조합은 구현 중 결정한다.
    - `func router(for tab: AppTab) -> any Routing`, `func router(forPresented id: PresentedRoute.ID) -> any Routing`
      (리뷰 R2-1: 모달 라우터는 모달 하나에 묶는다. `docs/reviews/feat-router-deeplink.md` D6)
      - 어댑터를 캐시해 같은 탭이면 같은 인스턴스를 돌려준다. 뷰가 다시 그려질 때 뷰모델이 새 라우터를 받지 않게 하기 위해서다.
    - `func handle(_ url: URL)`: 파싱하고, `nil`이면 무시한다. `isReady && gate.canOpen(link)`면 적용, 아니면 `pending = link`.
    - `func markReady()`: `isReady = true`로 바꾸고 `resumePending()`을 부른다.
    - `func resumePending()`: `pending`이 있고 게이트가 허용하면 적용하고 비운다.
    - `private func apply(_ link: DeepLink)`: `presented = nil` → `selectedTab = link.tab` → `paths[link.tab] = link.path`
  - `PresentedRoute.swift`: `struct PresentedRoute: Identifiable { let id: UUID; let root: AppRoute; let style: PresentationStyle; var path: [AppRoute] }`. UUID 생성은 주입이 필요한지 테스트 작성 시 판단한다.
  - `ScopedRouter.swift`: `@MainActor final class ScopedRouter: Routing`
    - 문맥은 `enum Scope { case tab(AppTab), presented(PresentedRoute.ID) }`이고 `AppRouter`를 `weak`로 참조한다.
      모달 문맥은 자기 모달이 떠 있을 때만 요청을 반영한다(D6).
    - `push`는 `AppRoute(route)`로 변환한 뒤 해당 문맥의 경로에 append한다. 변환에 실패하면 `assertionFailure`.
    - `present`는 `presented`를 설정한다. 이미 모달이 떠 있으면 교체한다(중첩 없음).
    - `dismiss`는 `presented = nil`.
  - `DeepLinkGate.swift`: `protocol DeepLinkGate`, `struct AllowAllDeepLinkGate: DeepLinkGate`
  - `App/Tests/AppRouterTests.swift`, `App/Tests/ScopedRouterTests.swift`(신규). 테스트용 거부 게이트는 테스트 파일 안에 `private`으로 둔다.
- 변경: 아직 뷰에 연결하지 않는다(다음 단계).
- 검증: 테스트 통과.

### 5. App: 뷰 연결과 라우터 소유권 이전
- 파일:
  - `App/Sources/AppDelegate.swift`(신규): `@MainActor final class AppDelegate: NSObject, UIApplicationDelegate`. `let router = AppRouter(gate: AllowAllDeepLinkGate())`
  - `App/Sources/TuistAppApp.swift`: `@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate`, `RootView(container: container, router: appDelegate.router)`
  - `App/Sources/Navigation/RootView.swift`
    - `@Bindable var router: AppRouter`, `TabView(selection: $router.selectedTab)`
    - `.sheet(item:)`와 `.fullScreenCover(item:)`는 `presented`의 `style`로 나눈 두 바인딩으로 연결한다.
    - 모달 내용은 자기 `NavigationStack(path:)`와 `appDestinations`를 가진다. 모달 화면에는 `router(forPresented: presented.id)`를 넘긴다(D1, D6). 모달 스택은 `$router[presentedPath: presented.id]`로 바인딩한다(R3-1).
    - `.onAppear { router.markReady() }`
  - `App/Sources/Navigation/TabRootView.swift`: `@State private var router = Router()`를 제거하고, `AppRouter`의 탭 경로 바인딩과 `router(for: tab)`을 사용한다.
  - `App/Sources/Navigation/View+AppDestinations.swift`: `appDestinations(_ container:, router: any Routing)`에서
    `navigationDestination(for: AppRoute.self) { container.makeView(for: $0, router: router) }` (리뷰 R1-5, D1)
  - `App/Sources/DI/AppContainer+Navigation.swift`(신규): `func makeView(for route: AppRoute, router: any Routing) -> some View`에서 `switch`로 피처별 `makeView`에 위임한다.
    라우터가 필요 없는 피처 화면은 분기에서 받지 않는다(리뷰 R1-5, D1).
  - `AppContainer+Home.swift:13`의 `makeHomeView(router:)` 시그니처는 유지한다.
- 검증:
  - 빌드와 테스트가 통과해야 한다.
  - 시뮬레이터에서 Home 목록 항목을 탭하면 상세로 push되고, 뒤로 가기가 동작해야 한다. 기존 동작과 같다.
  - 앱 실행은 `xcbuild.sh udid`의 기기로 한다.

### 6. 커스텀 URL 스킴과 `onOpenURL`
- 파일:
  - `Tuist/ProjectDescriptionHelpers/AppConstants.swift`: `public static let urlScheme = "tuistapp"`
  - `Tuist/ProjectDescriptionHelpers/Settings+Common.swift:62`: `runnable(displayName:urlSchemes: [String] = [])`. 비어 있지 않으면 `CFBundleURLTypes`를 추가한다.
  - `Tuist/ProjectDescriptionHelpers/Project+Templates.swift:175`: 앱 타깃은 `.runnable(urlSchemes: [AppConstants.urlScheme])`, 데모(`:283`)는 그대로 둔다.
  - `App/Sources/TuistAppApp.swift`: `RootView`에 `.onOpenURL { appDelegate.router.handle($0) }`
  - `App/Tests/TuistAppTests.swift`: Info.plist의 `CFBundleURLTypes`에 `AppConstants`와 같은 스킴이 있는지 확인하는 테스트를 추가한다. 기존 `fromMainBundle` 테스트와 같은 성격이다. App 코드에서 스킴 문자열을 쓸 곳이 없으면 "비어 있지 않은 스킴이 등록돼 있다"만 확인한다.
- 검증:
  - `tuist generate` 후 빌드와 테스트를 통과해야 한다.
  - 웜: 앱을 실행한 채로 `xcrun simctl openurl <udid> tuistapp://home/items/1` → Home 탭의 상세 화면.
  - 콜드: 앱을 종료한 뒤 같은 명령으로 같은 결과가 나와야 한다.
  - 파싱할 수 없는 URL(`tuistapp://nope`)이면 화면 변화가 없어야 한다.

### 7. 푸시 알림 탭 라우팅
- 파일:
  - `App/Sources/Push/PushPayload.swift`(신규): `enum PushPayload { static func link(from userInfo: [AnyHashable: Any]) -> URL? }`. 키는 `private enum Key { static let link = "link" }`에 둔다.
  - `App/Sources/AppDelegate.swift`
    - `application(_:didFinishLaunchingWithOptions:)`에서 `UNUserNotificationCenter.current().delegate = self`로 설정하고 `true`를 반환한다.
    - `UNUserNotificationCenterDelegate` 적합성을 추가한다. 격리 방식은 "알려진 함정"대로 1순위와 폴백 중 하나를 쓴다.
    - `didReceive`: 링크를 추출해 `router.handle(url)`을 부른다.
    - `willPresent`: `[.banner, .list, .sound]`를 반환한다.
  - `App/Tests/PushPayloadTests.swift`(신규)
- 검증:
  - 테스트가 통과하고, Swift 6 동시성 경고가 0개여야 한다.
  - 수동: `{"aps":{"alert":"t"},"link":"tuistapp://home/items/1"}`를 `xcrun simctl push <udid> <번들 ID> payload.apns`로 보내고 알림을 탭 → 상세 화면. 웜과 콜드를 모두 확인한다.
    - 시뮬레이터에서 알림을 표시하려면 권한이 필요할 수 있다. 필요하면 **커밋하지 않는 임시 코드**로 권한을 요청해 확인한다.
    - 권한 없이 가능한지는 **구현 중 확인**한다.

## 테스트 전략

새 테스트는 Swift Testing, 이름은 `동작_조건_기대결과` 형식이다.

| 테스트 | 검증하는 분기 |
|---|---|
| `RouterTests` (수정) | `TestRoute`가 `Route` 채택. `present` 후 `presented` 기록, `dismiss` 후 `nil` |
| `HomeRoutePathComponentsTests` | `["items","42"]` → `.detail("42")` / `["items"]` → nil / `["items",""]` → nil / `["unknown","1"]` → nil / `[]` → nil / 세그먼트 초과 `["items","1","x"]` → nil |
| `AppRouteTests` | `HomeRoute` → `.home(...)` / `Route`를 따르지만 App이 모르는 테스트 타입 → nil |
| `DeepLinkParserTests` | 커스텀 스킴 `tuistapp://home/items/1` → `(.home, [.home(.detail("1"))])` / `https://example.com/home/items/1`도 같은 결과(스킴 무관) / `tuistapp://home` → 탭 루트(빈 경로) / 알 수 없는 탭 → nil / 탭은 맞지만 하위 경로 파싱 실패 → nil / 쿼리·프래그먼트는 무시 |
| `AppRouterTests` | 준비 전 `handle` → 상태 불변, `markReady` 후 적용 / 준비 후 `handle` → 즉시 적용 / 적용 시 모달 닫힘 / 적용 시 기존 스택 교체 / 다른 탭으로 전환 / 게이트 거부 시 보류, 이후 `resumePending`으로 적용 / 보류 중 새 링크 → 마지막 것만 적용 / 파싱 실패 URL → 상태 불변 |
| `ScopedRouterTests` | 탭 문맥 `push` → 해당 탭 경로에만 추가 / `pop` 루트에서 무시 / `popToRoot` / 모달 문맥 `push` → 모달 경로에 추가 / `present` → `presented` 설정, 이미 떠 있으면 교체 / `dismiss` / 같은 탭에 대해 `router(for:)`가 같은 인스턴스 |
| `PushPayloadTests` | `link` 유효 → URL / 키 없음 → nil / 문자열 아님 → nil / 빈 문자열 → nil |
| `TuistAppTests` (추가) | Info.plist에 URL 스킴이 등록돼 있음 |
| `HomeViewModelTests` (기존) | 수정 없이 통과. `SpyRouter.pushedRoutes`가 유지되므로 |

`ScopedRouter`의 캐스팅 실패 시 `assertionFailure` 분기는 테스트하지 않는다. 테스트에서 트랩이 나기 때문이다. 대신 `AppRoute.init?` 실패 테스트로 판정 로직을 고정한다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| `nonisolated protocol` 선언이 MainActor 기본 격리 모듈에서 의도대로 동작하지 않아, `HomeRoute`를 비격리 문맥(파서·테스트)에서 쓸 때 격리 오류 | 중 | 1단계 빌드에서 확인. 안 되면 `Route`/`PresentationStyle`만 담는 파일에 격리 해제 방법을 찾는다. 최후 수단은 별도 경량 모듈(`NavigationCore`) 분리이며, 이 경우 계획을 갱신한다 |
| `FeatureInterface → Navigation` 의존으로 Interface가 SwiftUI를 전이적으로 끌어와 빌드 시간 증가 | 낮 | `Route.swift`는 SwiftUI를 import하지 않는다. 문제가 되면 위와 같은 모듈 분리 |
| SE-0470 격리 적합성을 현재 툴체인·설정에서 쓸 수 없음 | 중 | 폴백(nonisolated에서 `String` 추출 후 `MainActor.run`)이 이미 정의돼 있다 |
| 탭 전환과 스택 교체를 같은 틱에 해 애니메이션이 꼬이거나 스택이 적용되지 않음 | 중 | 수동 검증에서 확인. 문제 시 탭 전환 후 다음 런루프에 경로 교체(`Task { @MainActor in }`)하거나 트랜잭션에서 애니메이션 비활성. `AppRouterTests`는 상태만 검증하므로 영향 없음 <br>**확인(2026-09-21, iPhone 16e 시뮬레이터):** 시트가 떠 있을 때 딥링크를 열면 시트가 닫히고 Home 스택이 상세로 교체된다. 문제 없음. 탭 전환은 탭이 하나라 확인하지 못했다. 탭을 추가할 때 다시 확인한다 |
| 같은 방식의 모달을 교체(id만 바뀜)할 때 SwiftUI가 이전 항목을 닫으며 바인딩에 `nil`을 써, `subscript(presented:)` setter가 방금 띄운 모달까지 지움 | 중 | **확인(2026-09-21):** 시트 S1이 떠 있는 상태에서 같은 방식으로 S2를 `present`하면 S2가 남는다. 이 경로에서는 `nil`을 쓰지 않았다 |
| 모달 안에서 다른 방식의 모달로 교체할 때, 닫히는 모달의 스택 바인딩이 새 모달의 경로를 읽거나 덮어씀 | 중 | 모달 스택 바인딩을 `subscript(presentedPath: id)`로 모달 id에 묶었다(리뷰 R3-1, D6). **확인(2026-09-21):** 시트 A에서 `[A-1]`까지 push한 뒤 A의 라우터로 풀스크린 B를 띄우면, B는 빈 스택으로 뜨고 A의 경로가 넘어오지 않는다 |
| 화면이 로컬 상태로 띄운 알럿·시트 위에서 딥링크가 오면 그 모달이 닫히지 않음 | 중 | 라우터 소유 모달만 닫는다고 `Routing` 문서에 명시. 딥링크로 닫혀야 하는 모달은 `present`를 쓰도록 안내 |
| `ScopedRouter`를 뷰 body에서 매번 만들어 뷰모델이 재생성될 때 이전 라우터를 잃음 | 낮 | `AppRouter`가 문맥별로 캐시(테스트로 고정) |
| 푸시 payload 키 `link`가 서버 계약과 다름 | 중 | 상수 한 곳(`PushPayload.Key`). 서버와 합의 후 변경 |
| 시뮬레이터에서 알림 권한 없이 푸시 E2E 확인 불가 | 중 | 임시 코드로 확인하고 커밋하지 않는다. 단위 테스트로 payload와 라우터 동작은 고정 |
| 데모 앱의 `Router` 변경으로 `HomeDemoApp` 빌드 깨짐 | 낮 | 1단계 검증에 데모 타깃 빌드 포함 |

## 롤백

- 각 단계가 독립 커밋이므로 `git revert <커밋>`으로 역순 되돌린다. 7 → 6 → 5 순서로 되돌리면 앱은 기존 탭별 `Router` 구조로 돌아간다.
  1~4단계는 앱 동작을 바꾸지 않으므로 남겨 둬도 된다.
- 6단계를 되돌린 뒤에는 `tuist generate`를 다시 실행해 `CFBundleURLTypes`를 제거한다.
- 모든 변경은 `feat/router-deeplink` 브랜치에 있으므로, 병합 전이라면 브랜치를 버리는 것으로 끝난다.
