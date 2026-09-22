# Navigation

화면 이동 요청 창구. 피처는 "어디로 갈지"만 말하고, 그 값을 실제 화면·탭·모달로 바꾸는 일은 App이 한다.
딥링크와 푸시 알림도 같은 구조로 들어온다.

**iOS 17.0+ / Xcode 27+ / Swift 6 (MainActor 기본 격리)**

---

## 특징

- **피처는 프로토콜만 본다**: 뷰모델은 `Routing`을 주입받아 `push` / `pop` / `popToRoot` / `present` / `dismiss`를 요청한다. 구체 라우터를 모르므로 `SpyRouter`로 바꿔 테스트한다.
- **push 할 수 있는 값을 컴파일 타임에 제한**: `Route`를 따르는 값만 넘길 수 있다. 아무 `Hashable`이나 넘기는 실수가 빌드에서 막힌다.
- **피처끼리 구현을 import 하지 않는다**: 다른 피처로 갈 때도 그 피처 Interface의 Route 값만 쓴다. Route를 화면으로 바꾸는 것은 모든 피처를 아는 App 한 곳이다.
- **앱 전체 라우터 하나**: App의 `AppRouter`가 선택된 탭, 탭별 스택(`[AppRoute]`), 모달 한 단계를 소유한다. 뷰는 바인딩만 한다. 경로가 값 배열이라 내용을 검사하고 테스트할 수 있다.
- **딥링크·푸시 입구가 하나**: 커스텀 URL 스킴, 푸시 알림의 링크, (나중의) Universal Link가 모두 `AppRouter.handle(_:)`로 들어온다. 앱이 실행 중이든 종료 상태든 같은 결과가 나온다.
- **외부 입력에 안전**: 해석할 수 없는 URL·payload는 아무 일도 일으키지 않는다. 크래시나 빈 화면이 없다.
- **늦은 요청에 안전**: 모달마다 라우터가 따로 묶여 있어, 닫힌 모달이 비동기 작업 끝에 보낸 `push`·`dismiss`가 다음에 뜬 다른 모달을 건드리지 않는다.
- **인증 확장 지점**: `DeepLinkGate`로 링크를 지금 열지 판단한다. 거부한 링크는 보류했다가 로그인 후 이어서 연다. 지금은 모두 허용한다.

---

## 구성

이 모듈에는 피처가 보는 최소 표면만 있다. 앱 전체 상태는 모든 피처를 아는 App 타깃에 있다.

```
Modules/Core/Navigation/
├── Sources/
│   ├── Routing.swift            뷰모델이 이동을 요청하는 프로토콜
│   ├── Route.swift              push 가능한 값의 마커 프로토콜
│   ├── PresentationStyle.swift  .sheet / .fullScreenCover
│   └── Router.swift             데모 앱·프리뷰용 단독 라우터
├── Testing/Sources/
│   └── SpyRouter.swift          요청을 기록만 하는 테스트 더블 (NavigationTesting)
└── Tests/

App/Sources/
├── Navigation/
│   ├── AppRouter.swift          탭·스택·모달 상태, 딥링크 입구, 보류·재생
│   ├── ScopedRouter.swift       탭 하나·모달 하나 문맥의 Routing 어댑터
│   ├── AppRoute.swift           피처 Route 를 감싸는 스택 원소
│   ├── AppTab.swift             최상위 탭
│   ├── PresentedRoute.swift     라우터가 띄운 모달 한 단계
│   ├── DeepLink.swift           링크 목적지(탭 + 스택)
│   ├── DeepLinkParser.swift     URL → DeepLink
│   ├── DeepLinkGate.swift       링크를 지금 열어도 되는지
│   ├── RootView.swift / TabRootView.swift / View+AppDestinations.swift
├── DI/AppContainer+Navigation.swift   AppRoute → 화면
├── Push/PushPayload.swift              알림 payload → 링크 URL
└── AppDelegate.swift                   AppRouter 소유, 알림 탭 처리
```

의존 방향은 아래로만 흐른다. 피처 Interface가 `Route`를 채택하려고 Navigation에 의존한다.

```
App ──→ Feature ──→ FeatureInterface ──→ Navigation (Route)
 │         └──────→ Navigation (Routing)
 └──→ FeatureInterface, Navigation
```

---

## 시작하기

### 1. 피처 Interface에 Route 정의

```swift
// Modules/Features/Home/Interface/Sources/HomeRoute.swift
import Domain
import Navigation

public enum HomeRoute: Route {
    case detail(id: Item.ID)
}
```

연관값에는 엔티티가 아니라 **식별자만** 담는다. 딥링크로도 만들 수 있고, 이동한 화면이 항상 최신 데이터를 다시 읽는다.

Interface 타깃의 `Project.swift`에 `.module(.navigation)`을 추가한다.

```swift
Project.feature(
    name: "Home",
    interfaceDependencies: [.module(.domain), .module(.navigation)],
    ...
)
```

### 2. 뷰모델에서 이동 요청

```swift
import HomeInterface
import Navigation

@MainActor @Observable
public final class HomeViewModel {
    @ObservationIgnored private let router: any Routing

    public init(repository: any ItemRepository, router: any Routing) { ... }

    public func select(_ item: Item) {
        router.push(HomeRoute.detail(id: item.id))
    }
}
```

모달은 방식을 골라 띄운다. 이미 모달이 떠 있으면 교체된다(중첩하지 않는다).

```swift
router.present(HomeRoute.detail(id: id), style: .sheet)
router.dismiss()
```

뷰모델은 자기가 어느 탭·모달에 있는지 모른다. App이 문맥에 맞는 `Routing`을 넣어 준다.

### 3. App에 Route 연결

새 피처 Route를 앱에 알리는 곳은 세 군데다.

```swift
// App/Sources/Navigation/AppRoute.swift
enum AppRoute: Hashable {
    case home(HomeRoute)
    case transfer(TransferRoute)          // ① case 추가

    init?(_ route: some Route) {
        switch route {
        case let route as HomeRoute: self = .home(route)
        case let route as TransferRoute: self = .transfer(route)   // ② 분기 추가
        default: return nil
        }
    }
}

// App/Sources/DI/AppContainer+Navigation.swift
func makeView(for route: AppRoute, router: any Routing) -> some View {
    switch route {
    case let .home(route): makeView(for: route)
    case let .transfer(route): makeTransferView(for: route, router: router)   // ③ 화면
    }
}
```

`router`는 그 화면이 놓일 문맥(탭 또는 모달)의 라우터다. 화면의 뷰모델이 이동을 요청해야 하면 이 값을 넘긴다.
목적지 등록(`navigationDestination(for: AppRoute.self)`)은 이미 스택 루트마다 하나씩 붙어 있으므로 따로 추가하지 않는다.

②를 빠뜨리면 그 Route를 push할 때 디버그 빌드에서 `assertionFailure`가 이유를 알려 준다.
`AppRouteTests`에 새 Route가 감싸지는지 한 줄을 추가해 두면 빌드 전에 잡힌다.

---

## 딥링크

### URL 형식

첫 세그먼트가 탭, 나머지가 그 피처의 경로다. 스킴과 도메인은 보지 않는다.

| URL | 결과 |
|---|---|
| `tuistapp://home` | Home 탭 루트 |
| `tuistapp://home/items/42` | Home 탭, 스택 `[.home(.detail(id: "42"))]` |
| `https://example.com/home/items/42` | 위와 같음(Universal Link용) |
| `tuistapp://nope`, `tuistapp://home/unknown` | 무시 |

- 커스텀 스킴은 host가 첫 세그먼트이고, `http(s)`는 host가 도메인이라 경로만 쓴다. 쿼리와 프래그먼트는 무시한다.
- 탭 세그먼트와 스킴은 대소문자를 무시한다. 탭 뒤의 세그먼트(식별자 등)는 그대로 피처에 넘긴다.

링크를 열면 **모달을 닫고 → 탭을 바꾸고 → 그 탭의 스택을 교체**한다. 기존 스택에 덧붙이지 않으므로 같은 링크는 항상 같은 화면이 된다.

### 피처 경로 해석

URL 형식은 피처가 소유한다. Interface에 세그먼트 → Route 생성자를 둔다.

```swift
// Modules/Features/Home/Interface/Sources/HomeRoute+PathComponents.swift
public extension HomeRoute {
    /// ["items", "42"] → .detail(id: "42")
    init?(pathComponents: [String]) { ... }
}
```

탭 세그먼트와 피처 연결은 `DeepLinkParser`의 `TabSegment`와 `switch`에서 한다. 탭을 추가하면 여기에 분기를 늘린다.

### 스킴 설정

스킴은 `Tuist/ProjectDescriptionHelpers/AppConstants.swift`의 `urlScheme`이다. 템플릿으로 새 앱을 만들면 이 값만 바꾼다.
앱 타깃 Info.plist의 `CFBundleURLTypes`에만 등록되고, 데모 앱은 등록하지 않는다. 바꾼 뒤에는 `tuist generate`를 다시 실행한다.

### 콜드 스타트와 보류

콜드 스타트에서는 링크가 루트 화면보다 먼저 올 수 있다. `AppRouter`는 준비 전(`markReady()` 전)에 온 링크를 **마지막 하나만** 보류했다가 `RootView.onAppear`에서 연다.
`AppRouter`는 뷰가 아니라 `AppDelegate`가 소유한다. `didFinishLaunching`보다 먼저 생성되므로 어떤 순서로 콜백이 와도 받을 곳이 있다.

---

## 푸시 알림

알림을 탭하면 payload의 `link` 문자열을 딥링크와 같은 입구로 넘긴다.

```json
{ "aps": { "alert": "새 항목" }, "link": "tuistapp://home/items/42" }
```

- 키 이름은 `PushPayload.Key.link` 한 곳에 있다. **서버와 합의한 값으로 맞춘다.**
- `link`가 없거나 문자열이 아니거나 비어 있으면 무시한다.
- 앱을 쓰는 중에도 배너를 보여 준다(`willPresent` → `[.banner, .list, .sound]`). 그래야 탭해서 이동할 수 있다.
- 알림 권한 요청, 원격 알림 등록, APNs 토큰 전송은 이 모듈 범위가 아니다. 앱에 붙일 때 따로 구현한다.

---

## 모달

- 라우터가 띄우는 모달은 **한 단계**다. `present`를 다시 부르면 교체한다.
- 모달 안에는 자기 `NavigationStack`이 있다. 모달 안 화면의 `push`는 모달 스택에 쌓이고, 모달 뒤의 탭 스택은 그대로다.
- 모달 라우터는 그 모달(`PresentedRoute.id`)에 묶여 있다. 모달이 닫힌 뒤 온 요청은 무시된다.

**어떤 모달을 라우터로 띄우나**

| 라우터 `present` | 화면 로컬 상태 (`.alert`, `.confirmationDialog`, `.sheet(isPresented:)`) |
|---|---|
| 딥링크·푸시로 닫혀야 하는 화면, 다른 화면에서 띄워야 하는 화면 | 그 화면 안에서 끝나는 짧은 확인·입력 |
| 딥링크가 오면 라우터가 닫는다 | 라우터가 모르므로 딥링크가 와도 닫히지 않는다 |

---

## 인증이 필요한 목적지

`AppRouter(gate:)`에 `DeepLinkGate` 구현을 넣는다. 거부한 링크는 보류되고, 로그인을 마친 뒤 `resumePending()`을 부르면 이어서 열린다.

아래는 형태만 보여 주는 예시다. `SessionStore`와 "로그인이 필요한 목적지" 판단은 앱에 맞게 만든다.

```swift
@MainActor
struct SessionDeepLinkGate: DeepLinkGate {
    let session: SessionStore            // 예시: 로그인 상태를 가진 타입

    func canOpen(_ link: DeepLink) -> Bool {
        needsLogin(link) ? session.isLoggedIn : true
    }

    private func needsLogin(_ link: DeepLink) -> Bool { ... }   // 예시: 탭·경로로 판단
}

// 로그인 완료 후
appDelegate.router.resumePending()
```

---

## 알아 둘 동작

- 루트에서 `pop()`은 아무 일도 하지 않는다.
- `AppRoute`에 없는 Route를 push/present하면 디버그 빌드는 `assertionFailure`로 멈추고, 릴리스 빌드는 무시한다.
- 보류 중에 새 링크가 오면 이전 것은 버린다(마지막 것만 연다).
- 링크는 스택을 **교체**한다. 사용자가 쌓아 둔 스택은 사라진다.
- 탭 전환과 스택 교체를 같은 틱에 하는 동작은 탭이 하나라 아직 확인하지 않았다. 탭을 추가하면 시뮬레이터에서 한 번 확인한다.

---

## 테스트

### 뷰모델: `SpyRouter`

테스트 타깃에 `.testing(.navigation)`을 추가한다.

```swift
import NavigationTesting

let router = SpyRouter()
let viewModel = HomeViewModel(repository: stub, router: router)

viewModel.select(item)

#expect(router.pushedRoutes == [HomeRoute.detail(id: item.id)])
#expect(router.presentedRoutes == [.init(route: HomeRoute.detail(id: "1"), style: .sheet)])
#expect(router.dismissCount == 1)
```

기록 항목: `pushedRoutes`, `popCount`, `popToRootCount`, `presentedRoutes`, `dismissCount`.

### 라우팅 로직

App 테스트 타깃(`TuistAppTests`)에 있다. 피처를 추가하거나 URL 형식을 바꿀 때 여기를 함께 고친다.

| 테스트 | 지키는 것 |
|---|---|
| `AppRouteTests` | 모든 피처 Route가 `AppRoute`로 감싸진다 |
| `DeepLinkParserTests` | URL 형식, 스킴 무관, 대소문자, 잘못된 입력 |
| `HomeRoutePathComponentsTests` | Home 경로 세그먼트 |
| `AppRouterTests` | 보류·재생, 게이트, 스택 교체, 모달 바인딩 |
| `ScopedRouterTests` | 문맥별 push/pop, 모달 교체, 닫힌 모달의 늦은 요청 무시 |
| `PushPayloadTests` | payload → URL |
| `TuistAppTests` | Info.plist에 URL 스킴이 등록돼 있다 |

### 시뮬레이터에서 직접 확인

기기는 `./.claude/scripts/xcbuild.sh udid`의 값을 쓴다. 번들 ID는 Debug 빌드에서 `.dev`가 붙는다.

```bash
xcrun simctl openurl <udid> tuistapp://home/items/1
```

```bash
xcrun simctl push <udid> com.olivebridge.tuistapp.dev payload.apns
```

앱을 종료한 뒤 같은 명령을 보내면 콜드 스타트를 확인할 수 있다. 푸시 배너가 뜨려면 시뮬레이터에서도 알림 권한이 필요하다.

---

## 피처 데모 앱

데모 앱은 `AppRouter`를 볼 수 없으므로 이 모듈의 `Router`로 스택 하나를 흉내 낸다.

```swift
@State private var router = Router()

NavigationStack(path: $router.path) {
    HomeView(viewModel: HomeViewModel(repository: stub, router: router))
        .navigationDestination(for: HomeRoute.self) { route in ... }
}
```

`present`는 `router.presented`에 기록만 한다. 데모에서 모달을 보려면 이 값을 보고 직접 띄운다.

---

## 확장할 때

| 하려는 일 | 고칠 곳 |
|---|---|
| 새 피처 화면으로 이동 | 피처 Interface에 `Route` → `AppRoute` case·`init?` 분기 → `AppContainer.makeView(for:router:)` → `AppRouteTests` |
| 그 화면을 딥링크로 열기 | Interface에 `init?(pathComponents:)` → `DeepLinkParser` 분기 → 파서 테스트 |
| 탭 추가 | `AppTab` case → `TabRootView` 루트 화면 → `DeepLinkParser.TabSegment` → 탭 전환 테스트 |
| Universal Links | Associated Domains 엔타이틀먼트와 AASA 파일만 준비한다. 파서와 입구(`onOpenURL`)는 그대로 쓴다 |
| 모달 목적지로 가는 딥링크 | `DeepLink`에 모달 필드를 추가하고 `AppRouter.apply(_:)`에서 띄운다 |

범위 밖으로 남겨 둔 것: 모달 위의 모달, 경로 복원(`@SceneStorage`), Route → URL 역변환(공유 링크).
