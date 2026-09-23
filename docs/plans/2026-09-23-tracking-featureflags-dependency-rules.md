# Tracking·FeatureFlags 추상화와 의존 방향 강제

## 목표

- 모듈 매니페스트가 의존 방향 규칙을 어기면 `tuist generate`가 멈춘다. 예를 들어 Home의 `dependencies`에 `.module(.data)`나 `.module(.networking)`를 넣으면 실패하고, 실패한 매니페스트 경로가 나온다. `fatalError` 문구(모듈 이름과 고칠 위치 `Module.swift`)는 Tuist가 보여 주지 않으므로, 오류에 찍힌 `xcrun swift ... --tuist-dump` 명령을 직접 실행해 확인한다(구현 중 확인, 사용자 결정).
- 구현 타깃(모듈 구현, Interface, App 본 타깃)이 `*Testing`에 의존하면 `tuist generate`가 멈춘다.
- 지금 있는 매니페스트는 모두 검증을 통과한다. 규칙에 맞추려고 기존 매니페스트를 고치지 않는다.
- 새 Core 모듈 `Tracking`(이벤트 기록 프로토콜)과 `FeatureFlags`(Bool 플래그 조회 프로토콜)가 생긴다. 둘 다 Foundation과 os 외에는 import하지 않고, Feature가 의존할 수 있다.
- App이 Firebase를 초기화했으면 `FirebaseEventTracker`(Analytics)와 `RemoteConfigFeatureFlagProvider`(Remote Config)를 쓴다. 초기화하지 않았으면(Debug, 설정 파일 없음) 로그 기록기와 기본값 제공자를 쓴다. 이 선택 분기는 테스트로 고정한다.
- Release에서 Firebase를 초기화하면 Remote Config를 한 번 `fetchAndActivate`하고, 결과를 로그로 남긴다.
- Analytics는 IDFA를 수집하지 않는다(`FirebaseAnalyticsCore` 제품).
- `./.claude/scripts/xcbuild.sh test`와 `./.claude/scripts/xcbuild.sh build -configuration Release`가 통과한다.

## 범위 밖

- 실제 이벤트나 플래그 정의, Home에서의 호출. 이번에는 추상화와 연결만 하고, 어떤 이벤트를 남길지는 제품 결정이다.
- 사용자 ID·사용자 속성(`setUserID`, `setUserProperty`), 동의 UI, ATT 요청 흐름.
- Remote Config 실시간 리스너(`addOnConfigUpdateListener`), Bool이 아닌 값(문자열·숫자·JSON), 디버그용 로컬 오버라이드 메뉴.
- `tuist inspect dependencies` CI 단계(사용자 결정. 선언하지 않은 import는 `enforceExplicitDependencies`가 이미 막는다).
- 외부 패키지(`.external`) 의존 규칙. 예를 들어 Domain이 외부 패키지를 쓰는 것은 이번 검증 대상이 아니다. 검사는 모듈 사이(`.project`)만 한다.
- `FirebaseBootstrap`의 파일 위치(`App/Sources/Diagnostics/`). 세 기능이 함께 쓰게 되지만 옮기지 않는다.
- `Settings+Common.swift:74`의 `ANALYTICS_APP_KEY` Info.plist 키와 `Configurations/ClientKeys.xcconfig.example:37`. 코드에서 읽는 곳이 없는 기존 자리표시자이고 Firebase와 관계없다. 그대로 둔다.
- App Store 개인정보 라벨 갱신. 출시 전에 사람이 직접 한다.

## 전제

### 환경
- iOS 17.0(`Tuist/ProjectDescriptionHelpers/AppConstants.swift:23`), Swift 6 언어 모드, Xcode 27, Tuist 4.208.0(`mise.toml`).
- `main`에는 커밋할 수 없다(훅이 막는다). 작업 브랜치를 먼저 만든다. 예: `feat/tracking-featureflags`.
- `Tuist.swift:11-16`: `enforceExplicitDependencies: true`. 타깃이 import하는 모듈은 모두 그 타깃의 의존성에 적는다.
- `xcbuild.sh`는 `tuist generate`를 하지 않는다. 매니페스트나 헬퍼를 바꾼 단계에서는 `mise exec -- tuist generate --no-open`을 먼저 돌린다.
- `ProjectDescriptionHelpers`에는 테스트 타깃이 없다. 헬퍼 검증은 generate를 실제로 돌려서 확인한다.
- `Tuist/Package.swift`에 firebase-ios-sdk 12.19.2가 이미 있다. 새 패키지는 추가하지 않고 같은 패키지의 제품만 App 타깃에 더한다.

### 의존 방향 검증에 쓸 사실
- `TargetDependency`(ProjectDescription)는 `Codable, Hashable, Sendable`인 enum이다. `.module(_)`와 `.testing(_)`(`Module.swift:95`, `:103`)는 `.project(target: String, path: Path, status:, condition:)`를 만든다. 검증은 `case let .project(target, _, _, _)`로 대상 이름을 꺼내 쓴다.
- 대상 이름으로 모듈을 찾는 규칙: `Module.all`의 각 모듈 m(피처는 `.featureInterface(n)`도 함께)에 대해 `m.name`이면 (m, Testing 아님), `"\(m.name)Testing"`이면 (m, Testing)이다. 단, 피처의 `{n}Testing`은 Interface의 목이고 Interface에만 의존하므로 (`.featureInterface(n)`, Testing)으로 본다. 그래야 다른 피처의 테스트·데모가 쓸 수 있다(구현 중 확인, 사용자 결정). 어디에도 맞지 않는 `.project`는 등록부 밖의 모듈이므로 멈춘다.
- Tuist 4.208.0은 매니페스트 프로세스의 stderr를 버린다. `fatalError` 문구는 generate 출력, `--verbose`, 세션 로그, `tuist dump` 어디에도 나오지 않고 `Project.swift ... terminated after receiving a signal with code 5`만 나온다. 기존 `validateRegistration`도 같다(구현 중 확인).
- 같은 프로젝트 안의 연결(`.target(name:)`, 예: 구현→Interface)과 `.external`, `.sdk`는 검사하지 않는다.
- 현재 유일한 generate 시점 검증은 `Module.validateRegistration`(`Module.swift:137`)이다. 어기면 `fatalError`로 멈춘다. 방향 검증도 같은 방식을 쓴다(`ProjectDescription`에 검증 오류를 던지는 공식 API가 있는지는 확인하지 못했다).
- 템플릿 진입점:
  - `Project.feature`(`Project+Templates.swift:28`, 검증 호출은 `:40`): `interfaceDependencies`, `dependencies`, `testDependencies`, `testingDependencies`, `demoDependencies`
  - `Project.core`(`:108`, 검증 호출은 `:120`): `dependencies`, `testDependencies`, `testingDependencies`, `demoDependencies`
  - `Project.app`(`:165`): `dependencies`, `testDependencies`
- 규칙의 원문은 `Module.swift:15-37`의 주석 다이어그램이다. 코드로 옮기면서 주석이 코드(`mayDepend`)를 가리키게 바꾼다.

### 허용 규칙(구현 타깃 기준, 이번에 코드로 옮길 표)

| 의존하는 쪽 | 의존해도 되는 모듈 |
|---|---|
| `.feature(_)` | `.featureInterface(_)`(모든 피처), `.domain`, `.designSystem`, `.navigation`, `.tracking`, `.featureFlags` |
| `.featureInterface(_)` | `.domain`, `.navigation` |
| `.data` | `.domain`, `.diagnostics`, `.networking` |
| `.domain`, `.designSystem`, `.networking`, `.navigation`, `.diagnostics`, `.tracking`, `.featureFlags` | 없음 |

- 피처 구현은 다른 피처의 **구현**(`.feature(_)`)에 의존할 수 없다.
- 테스트·Testing·데모 타깃은 그 모듈의 구현이 의존해도 되는 모듈과, 그 모듈들의 `*Testing`에 의존할 수 있다. 피처는 구현과 Interface 규칙을 합친 범위를 쓴다(구현 규칙이 Interface 규칙을 포함한다).
- App 본 타깃은 어떤 모듈이든 의존할 수 있지만 `*Testing`에는 의존할 수 없다. App 테스트 타깃은 제한하지 않는다.
- 기존 매니페스트 대조(모두 통과해야 한다): Home 구현(domain, designSystem, navigation), Home Interface(domain, navigation), Home 테스트(domain, Testing(domain), Testing(navigation)), Home 데모(domain, Testing(domain), designSystem, navigation), Data(domain, diagnostics, networking), Data 테스트(domain, networking, diagnostics, Testing(diagnostics)). 나머지 Core 모듈은 `.project` 의존성이 없다.

### 기존 패턴(Diagnostics, 그대로 복제한다)
- Core 프로토콜: `Modules/Core/Diagnostics/Sources/DiagnosticEventSink.swift:10` `public protocol DiagnosticEventSink: Sendable`.
- Core 기본 구현: `Modules/Core/Diagnostics/Sources/LoggerDiagnosticSink.swift`. `os.Logger`만 쓰는 `public struct`이고, 문구는 `static func message(for:)`로 분리해 테스트한다.
- Testing 스파이: `Modules/Core/Diagnostics/Testing/Sources/SpyDiagnosticEventSink.swift:12`. `public final class`가 `OSAllocatedUnfairLock<[T]>`에 기록을 저장한다. `@unchecked Sendable`은 쓰지 않는다.
- App 전송 구현: `App/Sources/Diagnostics/CrashlyticsDiagnosticSink.swift:16`. 저장 프로퍼티가 없는 struct이고, Firebase 인스턴스(Sendable 아님)를 저장하지 않고 호출할 때마다 받는다. 그래서 Debug 테스트에서 만들기만 해서는 Firebase를 부르지 않는다.
- 조립: `App/Sources/DI/AppContainer.swift:24-26`에서 `FirebaseBootstrap.configureIfAvailable()`가 **싱크를 고르기 전에** 먼저 실행된다. `makeDiagnosticSink(firebaseDecision:logger:)`(`:60`)가 `.configure`일 때만 Crashlytics를 고르고, 건너뛴 이유를 로그로 남긴다. 로그 카테고리 상수는 파일 하단의 `private enum LogCategory`(`:77`)에 둔다.
- 선택 분기 테스트: `App/Tests/AppContainerDiagnosticSinkTests.swift`. `@MainActor @Suite`, `Logger(.disabled)`, `#expect(sink is CrashlyticsDiagnosticSink)` 형태.
- 모듈 등록: `Module.swift`의 `case`(`:60` 근처), `name`(`:79` 근처), `path`의 Core 목록(`:87`), `Module.all`(`:115`), 주석 다이어그램(`:15-37`). 워크스페이스 스킴은 `Scheme+Workspace.swift:24-27`이 `Module.all`에서 읽는다. `Workspace.swift`는 `Modules/**`를 자동으로 포함한다.
- 루트 `README.md:36-45`에 모듈 트리가 있다.
- App 매니페스트 `App/Project.swift:24-26`: "모듈은 Firebase를 모른다". Firebase 제품은 App 타깃에만 `.external`로 더한다. `-ObjC` 링크 플래그는 이미 있다(`:29`).
- Info.plist는 `Settings+Common.swift:64` `InfoPlist.runnable(displayName:urlSchemes:)`가 만든다. 앱과 데모 앱이 함께 쓴다.

### Firebase API(12.19.2, iOS 17에서 사용 가능, 폴백 불필요)
- Analytics: `Analytics.logEvent(_ name: String, parameters: [String: Any]?)` 클래스 메서드. 인스턴스를 저장하지 않는다. 파라미터 값은 문자열이나 숫자(NSNumber)다.
- 제품: `FirebaseAnalyticsCore`는 `GoogleAppMeasurementCore`에 의존한다(IDFA 수집 없음). `FirebaseAnalytics`는 `GoogleAppMeasurement`를 쓴다. 두 제품 모두 바이너리 타깃 `FirebaseAnalytics`를 포함하므로 소스에서는 `import FirebaseAnalytics`를 쓴다. `.external(name: "FirebaseAnalyticsCore")`만으로 이 import가 `enforceExplicitDependencies`를 통과한다(구현 중 확인: generate, Debug 테스트, Release 빌드 성공).
- Remote Config:
  - `RemoteConfig.remoteConfig()`는 Sendable이 아니다. 저장하지 않고 호출할 때마다 받는다(`FIRRemoteConfig.h:204-205`, `NS_SWIFT_SENDABLE` 없음).
  - `configValue(forKey:) -> RemoteConfigValue`. `.boolValue`, `.source: RemoteConfigSource`(`.remote`, `.default`, `.static`. `.static`은 값이 없다는 뜻, `FIRRemoteConfig.h:116-120`).
  - `fetchAndActivate(completionHandler:)`. 클로저는 `NS_SWIFT_SENDABLE`(`:326`)이고, 상태는 `RemoteConfigFetchAndActivateStatus`다. case는 `.successFetchedFromRemote`, `.successUsingPreFetchedData`, `.error`다(구현 중 확인, `FIRRemoteConfig.h:64-72`).
  - `minimumFetchInterval`은 기본 12시간이고 그대로 둔다. 이 간격 안에서는 받아둔 값을 적용한다.
  - 적용된(active) 값은 기기에 남아 다음 실행으로 이어진다. 그래서 `fetchAndActivate`가 끝나기 전에는 지난 실행에서 적용된 값을 읽고, 한 번도 받은 적이 없으면 `.static`이다.
  - `setDefaults`는 쓰지 않는다. 기본값은 코드의 `FeatureFlag.defaultValue`가 유일한 출처다.
- 두 제품 모두 `FirebaseApp.configure()` 뒤에만 쓴다. 설정 파일(`GoogleService-Info.plist`)은 Crashlytics와 같이 쓴다. Debug에서는 `FirebaseBootstrap`이 초기화를 건너뛴다.
- Info.plist에 `GOOGLE_ANALYTICS_REGISTRATION_WITH_AD_NETWORK_ENABLED = NO`를 앱 타깃에만 넣는다(광고 네트워크 등록 끄기).

### 알려진 함정
- 모듈 이름으로 `Analytics`나 `RemoteConfig`를 쓰면 App에서 Firebase 클래스 이름과 충돌한다. 그래서 `Tracking`과 `FeatureFlags`를 쓴다.
- Firebase 이벤트 이름과 파라미터 제약은 Core에서 검증하지 않는다. `FIRAnalytics.h`에서 확인한 길이·허용 문자·예약 접두사·예약 이름을 `Tracking/README.md`에 적었다. 파라미터 개수 한도는 헤더에 없어 적지 않았다(구현 중 확인).
- 머지되지 않은 `feat/module-scaffold-rename` 브랜치의 `Scripts/new-module.sh`가 `Module.swift`의 마커 주석 위치에 등록 줄을 넣는다. 이 계획도 `Module.swift`를 고치므로 나중에 머지하면 충돌할 수 있다. 새 Core 모듈을 스크립트로 만들면 `mayDepend`에 규칙이 없어 다른 모듈이 의존하는 순간 generate가 멈춘다. 이 동작은 의도한 것이며, 메시지가 `mayDepend`를 가리키게 한다. (리뷰 1라운드 후: 이 브랜치는 이미 머지된 origin/main 위로 옮겼다. 메시지가 보이지 않으므로 `new-module.sh` core 안내와 `case core` 주석에 `mayDepend` 규칙을 더하라고 적었다. `docs/reviews/feat-tracking-featureflags.md` D3·D4)

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 방향 강제 수단 | 헬퍼에서 generate 시점에 검증하고 `fatalError`로 멈춘다. `inspect dependencies`는 넣지 않는다 | 사용자 결정. 선언하지 않은 import는 `enforceExplicitDependencies`가 이미 막는다. 플랫폼 조사가 권한 "헬퍼 + inspect" 조합은 이 저장소에서는 이득이 작고, 잘못 잡는 사례가 보고되어 있다 |
| 규칙을 둘 곳 | `Module`에 `mayDepend(on:)` 규칙을 두고 `Project.feature/core/app`이 검사한다 | 규칙은 모듈 등록부와 함께 두고, 모든 모듈이 템플릿을 거치므로 검사 누락이 없다. 오류 방식은 `validateRegistration`과 같다 |
| 검사 대상 | `.project` 의존만 검사한다. `.target`, `.external`, `.sdk`는 검사하지 않는다 | 계층 규칙은 모듈 사이의 문제다. 외부 패키지 규칙은 범위 밖이다 |
| 프로토콜 위치 | Core 모듈 둘(`Tracking`, `FeatureFlags`) | 사용자 결정. Diagnostics를 분리한 선례를 따르고, 필요한 쪽만 의존한다. Domain의 정의(엔티티, UseCase, Repository)를 지킨다 |
| 플래그 반영 시점 | 시작할 때 `fetchAndActivate` 한 번 | 사용자 결정. 가장 단순하다. 세션 초반에 값이 한 번 바뀔 수 있고, 이미 읽은 화면은 다시 읽지 않는다 |
| 플래그 타입 | Bool만. `FeatureFlag(key:defaultValue:)`. 피처가 자기 모듈에서 `extension FeatureFlag { static let … }`으로 선언한다 | 플래그라는 용도에 맞춘다. 기본값이 코드 한 곳에 있어 plist 기본값과 어긋날 일이 없다 |
| IDFA | 수집하지 않는다. `FirebaseAnalyticsCore` 제품만 쓴다 | 사용자 결정. ATT 프롬프트와 `NSUserTrackingUsageDescription`이 필요 없다 |
| Sendable | Firebase 어댑터는 저장 프로퍼티가 없는 struct로 두고 Firebase 객체를 호출할 때마다 받는다 | 플랫폼 조사는 `@unchecked Sendable`을 권했지만 `.claude/rules/swift.md`가 금지한다. `CrashlyticsDiagnosticSink`가 같은 방식으로 이미 해결했다 |
| 기본 구현 | Core에 `LoggerEventTracker`와 `DefaultFeatureFlagProvider`를 `public`으로 둔다 | `LoggerDiagnosticSink`처럼 Debug, 데모 앱, 프리뷰가 Firebase 없이 쓴다 |
| 이벤트 파라미터 값 | `TrackingValue`(`string`, `int`, `double`) | Firebase가 받는 문자열과 숫자에 맞춘다. Bool은 변환 규칙이 모호해서 넣지 않는다 |

## 변경 계획

각 단계는 독립적으로 빌드가 통과해야 하고, 커밋 하나 분량이다.

### 1. 의존 방향 검증 헬퍼

- 파일: `Tuist/ProjectDescriptionHelpers/Module.swift`
  - `// MARK: - 의존 규칙` extension을 추가한다.
    - `func mayDepend(on other: Module) -> Bool`: 위 허용 규칙 표를 `switch (self, other)`로 옮긴다. 나열하지 않은 조합은 `false`다.
    - `internal static func resolve(target: String) -> (module: Module, isTesting: Bool)?`: `Module.all`(피처는 Interface까지 펼쳐서)에서 이름으로 찾는다.
    - `internal enum DependencyRole { case implementation, support }`: `support`는 테스트, Testing, 데모 타깃이다.
    - `internal static func validateDependencies(of owner: Module, role: DependencyRole, targetName: String, dependencies: [TargetDependency])`: `.project`만 꺼내 검사한다. 대상을 찾지 못하거나, `implementation`인데 Testing이거나, `mayDepend`가 `false`면 `fatalError`로 멈춘다. 메시지 예: `"Home → Data 의존은 허용되지 않습니다. 규칙은 Tuist/ProjectDescriptionHelpers/Module.swift 의 mayDepend(on:) 에 있습니다."` 메시지의 고정 문구는 파일 하단 `private enum`에 모은다.
    - `internal static func validateAppDependencies(_ dependencies: [TargetDependency], targetName: String)`: `*Testing`이면 멈춘다(메시지에 타깃 이름을 넣기 위해 `targetName`을 더했다).
    - 구현 중 추가: 템플릿 함수가 SwiftLint `function_body_length`(50줄)를 넘지 않도록 `validateModuleDependencies(of:dependencies:supportDependencies:)`(구현 + 지원 타깃)와 `validateFeatureDependencies(name:interface:implementation:support:)`(Interface까지)로 묶었다. 지원 타깃 세 개(테스트, Testing, 데모)는 합쳐서 한 번에 검사하고 메시지에는 `{name}Tests/Testing/Demo`로 나온다.
  - 주석 다이어그램(`:15-37`)에 "이 규칙은 `mayDepend(on:)`이 generate 시점에 강제한다"를 더한다.
- 파일: `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`
  - `Project.feature`(`:40` 바로 뒤): Interface는 `owner: .featureInterface(name)`, `role: .implementation`으로 `interfaceDependencies`를 검사한다. 구현은 `owner: .feature(name)`, `.implementation`으로 `dependencies`를 검사한다. `testDependencies`, `testingDependencies`, `demoDependencies`는 `owner: .feature(name)`, `.support`로 검사한다.
  - `Project.core`(`:120` 바로 뒤): 모듈은 `Module.all`에서 이름으로 찾는다(`validateRegistration`이 존재를 보장한다. 찾지 못하면 `preconditionFailure`). `dependencies`는 `.implementation`으로, 나머지는 `.support`로 검사한다.
  - `Project.app`: `dependencies`만 `validateAppDependencies`로 검사한다.
- 검증:
  - `mise exec -- tuist generate --no-open`가 성공한다(기존 매니페스트가 모두 통과한다).
  - 아래를 하나씩 **임시로** 넣고 generate가 멈추는지, 메시지가 무엇인지 확인한 뒤 되돌린다. 커밋하지 않는다.
    1. `Modules/Features/Home/Project.swift`의 `dependencies`에 `.module(.data)`를 넣는다 → 멈춘다
    2. 같은 곳에 `.module(.networking)` → 멈춘다
    3. 같은 곳에 `.testing(.domain)` → 멈춘다(구현이 Testing에 의존)
    4. `interfaceDependencies`에 `.module(.designSystem)` → 멈춘다
    5. `Modules/Core/Domain/Project.swift`에 `dependencies: [.module(.data)]` → 멈춘다
    6. `App/Project.swift`의 `dependencies`에 `.testing(.domain)` → 멈춘다
  - `fatalError` 메시지가 generate 출력에 어떤 모양으로 나오는지 기록해 커밋 메시지나 PR 본문에 적는다(**구현 중 확인**).
  - `./.claude/scripts/xcbuild.sh build`

### 2. Tracking 모듈

- 파일(새로 만든다):
  - `Modules/Core/Tracking/Project.swift`: `Project.core(name: "Tracking", hasTestingSupport: true)`. 주석은 Diagnostics 매니페스트와 같은 형식이다(Foundation과 os만, 전송 수단은 App이 꽂는다).
  - `Sources/TrackingValue.swift`: `public enum TrackingValue: Sendable, Equatable { case string(String), int(Int), double(Double) }`
  - `Sources/TrackingEvent.swift`: `public struct TrackingEvent: Sendable, Equatable { public let name: String; public let parameters: [String: TrackingValue] }`, `public init(name:parameters: = [:])`
  - `Sources/EventTracking.swift`: `public protocol EventTracking: Sendable { func track(_ event: TrackingEvent) }`. 동기로 호출하고 실패를 돌려주지 않는다(전송 수단이 대기열을 맡는다).
  - `Sources/LoggerEventTracker.swift`: `public struct LoggerEventTracker: EventTracking`, `public init(logger: Logger)`. `track`은 `logger.info`로 남긴다. 이벤트 이름은 `.public`, 파라미터는 사용자 값이 들어갈 수 있으므로 `.private`로 남긴다. `static func message(for:)`는 키 순서로 정렬한 문구를 돌려주며 테스트 대상이다.
  - `Testing/Sources/SpyEventTracker.swift`: `public final class SpyEventTracker: EventTracking`. `OSAllocatedUnfairLock<[TrackingEvent]>`에 기록하고 `public var events: [TrackingEvent]`로 노출한다. `SpyDiagnosticEventSink`와 같은 형태다.
  - `Tests/LoggerEventTrackerTests.swift`
  - `README.md`: 역할, 쓰는 법(피처가 `any EventTracking`을 생성자로 받는다), 이벤트 이름 상수는 피처 모듈의 `enum` 네임스페이스에 둔다는 규칙.
- 파일(고친다):
  - `Tuist/ProjectDescriptionHelpers/Module.swift`: `case tracking`(주석은 Foundation과 os만), `name` → `"Tracking"`, `path`의 Core 목록, `Module.all`, 다이어그램에 `Feature ──→ Tracking`과 `App ──→ Tracking`을 더한다. `mayDepend`는 `.feature(_) → .tracking`을 허용한다.
  - `README.md:36-45` 모듈 트리에 `Tracking/`을 한 줄 더한다.
- 검증: generate가 성공하고, `./.claude/scripts/xcbuild.sh test -only-testing:TrackingTests`가 통과한다.

### 3. FeatureFlags 모듈

- 파일(새로 만든다):
  - `Modules/Core/FeatureFlags/Project.swift`: `Project.core(name: "FeatureFlags", hasTestingSupport: true)`
  - `Sources/FeatureFlag.swift`: `public struct FeatureFlag: Hashable, Sendable { public let key: String; public let defaultValue: Bool }`, `public init(key:defaultValue:)`. 문서 주석에 "피처가 자기 모듈에서 `extension FeatureFlag { static let … }`으로 선언한다"를 적는다.
  - `Sources/FeatureFlagProviding.swift`: `public protocol FeatureFlagProviding: Sendable { func isEnabled(_ flag: FeatureFlag) -> Bool }`. 동기로 읽고, 원격 값이 없으면 `defaultValue`를 돌려준다는 계약을 적는다.
  - `Sources/DefaultFeatureFlagProvider.swift`: `public struct`. 항상 `flag.defaultValue`를 돌려준다.
  - `Testing/Sources/StubFeatureFlagProvider.swift`: `public struct StubFeatureFlagProvider: FeatureFlagProviding`, `public init(overrides: [FeatureFlag: Bool] = [:])`. `overrides[flag] ?? flag.defaultValue`. 값이 바뀌지 않으므로 잠금이 필요 없다.
  - `Tests/DefaultFeatureFlagProviderTests.swift`
  - `README.md`: 역할, 플래그 선언법, 값이 반영되는 시점(시작할 때 받아서 적용하므로 세션 초반에 한 번 바뀔 수 있고, 이미 읽은 화면은 다시 읽지 않는다).
- 파일(고친다): `Module.swift`(case, name, path, all, 다이어그램, `mayDepend`에서 `.feature(_) → .featureFlags` 허용), `README.md` 모듈 트리.
- 검증: generate가 성공하고, `./.claude/scripts/xcbuild.sh test -only-testing:FeatureFlagsTests`가 통과한다.

### 4. App: Firebase Analytics 연결

- 파일: `Tuist/ProjectDescriptionHelpers/Settings+Common.swift:64`
  - `runnable`에 `additionalEntries: [String: Plist.Value] = [:]` 매개변수를 더하고 plist에 합친다.
- 파일: `Tuist/ProjectDescriptionHelpers/Project+Templates.swift:165`
  - `Project.app`에 `additionalInfoPlist: [String: Plist.Value] = [:]`를 더하고 `.runnable(urlSchemes:additionalEntries:)`로 넘긴다.
- 파일: `App/Project.swift`
  - `dependencies`에 `.module(.tracking)`과 `.external(name: "FirebaseAnalyticsCore")`를 더한다. 주석에 "IDFA 없는 제품. IdentitySupport는 넣지 않는다"를 적는다. 기존 "모듈은 Firebase를 모른다" 주석을 Analytics까지 포함하도록 고친다.
  - `additionalInfoPlist: ["GOOGLE_ANALYTICS_REGISTRATION_WITH_AD_NETWORK_ENABLED": false]`를 넘기고 이유를 주석으로 남긴다.
- 파일(새로 만든다): `App/Sources/Tracking/FirebaseEventTracker.swift`
  - `struct FirebaseEventTracker: EventTracking`. 저장 프로퍼티를 두지 않는다. `track`은 `Analytics.logEvent(event.name, parameters: Self.parameters(for: event))`를 부른다.
  - `static func parameters(for event: TrackingEvent) -> [String: Any]?`: 비어 있으면 `nil`을 돌려준다. `.string` → `String`, `.int` → `Int`, `.double` → `Double`.
- 파일: `App/Sources/DI/AppContainer.swift`
  - `let eventTracker: any EventTracking`를 더한다. 피처에 주입하는 건 범위 밖이지만 조립 지점에서 하나로 만들어 둔다.
  - `static func makeEventTracker(firebaseDecision:logger:) -> any EventTracking`: `.configure`면 `FirebaseEventTracker()`, 아니면 `LoggerEventTracker(logger:)`. 건너뛴 이유는 `makeDiagnosticSink`가 이미 로그로 남기므로 다시 남기지 않는다.
  - `LogCategory`에 `tracking`을 더한다. 문서 주석의 구현 타입 목록에 새 타입을 더한다.
- 파일(새로 만든다): `App/Tests/AppContainerEventTrackerTests.swift`, `App/Tests/FirebaseEventTrackerTests.swift`
- 검증:
  - generate가 성공한다. `import FirebaseAnalytics`가 명시적 의존성 검사를 통과하는지 확인한다. 통과하지 못하면 `.external` 이름을 바꿔 보고, 결과를 이 문서의 전제에 반영한다(**구현 중 확인**).
  - `./.claude/scripts/xcbuild.sh test`
  - `./.claude/scripts/xcbuild.sh build -configuration Release`
  - 생성된 앱 Info.plist(`App/Derived/InfoPlists/`)에 키가 들어가고, 데모 앱 plist에는 없는지 확인한다.

### 5. App: Remote Config 연결

- 파일: `App/Project.swift`
  - `dependencies`에 `.module(.featureFlags)`와 `.external(name: "FirebaseRemoteConfig")`를 더한다.
- 파일(새로 만든다): `App/Sources/FeatureFlags/RemoteConfigFeatureFlagProvider.swift`
  - `struct RemoteConfigFeatureFlagProvider: FeatureFlagProviding`. 저장 프로퍼티를 두지 않는다.
  - `isEnabled`: `let value = RemoteConfig.remoteConfig().configValue(forKey: flag.key)` → `Self.resolve(source: value.source, remoteValue: value.boolValue, defaultValue: flag.defaultValue)`
  - `static func resolve(source:remoteValue:defaultValue:) -> Bool`: `.static`이면 `defaultValue`, 아니면 `remoteValue`. 판정만 분리해 테스트한다.
  - `static func fetchAndActivate(logger: Logger)`: `RemoteConfig.remoteConfig().fetchAndActivate { status, error in … }`. 클로저는 `@Sendable`이고 `Logger`는 Sendable이다. 오류는 `logger.error`로 남기고 그 밖의 처리는 하지 않는다. 받지 못해도 적용된 값이나 기본값으로 계속 동작하기 때문이며, 이 이유를 주석으로 적는다. 성공하면 상태를 `logger.info`로 남긴다. 로그 문구는 파일 하단 `private enum`에 둔다.
- 파일: `App/Sources/DI/AppContainer.swift`
  - `let featureFlags: any FeatureFlagProviding`를 더한다.
  - `static func makeFeatureFlagProvider(firebaseDecision:) -> any FeatureFlagProviding`: `.configure`면 `RemoteConfigFeatureFlagProvider()`, 아니면 `DefaultFeatureFlagProvider()`.
  - `init`에서 `firebaseDecision == .configure`일 때만 `RemoteConfigFeatureFlagProvider.fetchAndActivate(logger:)`를 부른다. `FirebaseBootstrap.configureIfAvailable()` 뒤에 둔다.
  - `LogCategory`에 `featureFlags`를 더하고, 문서 주석의 구현 타입 목록을 갱신한다.
- 파일(새로 만든다): `App/Tests/AppContainerFeatureFlagProviderTests.swift`, `App/Tests/RemoteConfigFeatureFlagProviderTests.swift`
- 검증:
  - generate가 성공한다.
  - `./.claude/scripts/xcbuild.sh test`
  - `./.claude/scripts/xcbuild.sh build -configuration Release`

## 테스트 전략

새 테스트는 모두 Swift Testing으로 쓰고, 이름은 `동작_조건_기대결과` 형식이다.

| 테스트 | 검증하는 분기 |
|---|---|
| `LoggerEventTrackerTests` | 파라미터가 없을 때 문구 / 여러 파라미터가 키 순서로 정렬되는지 / 세 가지 값 타입의 표기 |
| `DefaultFeatureFlagProviderTests` | `defaultValue`가 `true`, `false`일 때 각각 그대로 돌려준다(파라미터화) |
| `FirebaseEventTrackerTests` | 파라미터가 비면 `nil` / `.string`, `.int`, `.double`이 각각 `String`, `Int`, `Double`로 바뀐다 |
| `AppContainerEventTrackerTests` | `.configure` → `FirebaseEventTracker` / `.skipDebug`, `.skipMissingConfigFile` → `LoggerEventTracker`(파라미터화) |
| `RemoteConfigFeatureFlagProviderTests` | `resolve`: `.static`이면 기본값 / `.remote`면 원격 값 / `.default`면 원격 값(`setDefaults`를 쓰지 않으므로 나오지 않지만 규칙을 고정한다) |
| `AppContainerFeatureFlagProviderTests` | `.configure` → `RemoteConfigFeatureFlagProvider` / 건너뜀 → `DefaultFeatureFlagProvider` |

- `FirebaseEventTracker`와 `RemoteConfigFeatureFlagProvider`는 저장 프로퍼티가 없으므로 만들기만 해서는 Firebase를 부르지 않는다. Debug 테스트 호스트에서도 안전하다(`AppContainerDiagnosticSinkTests`와 같은 전제).
- `SpyEventTracker`와 `StubFeatureFlagProvider`는 지금 쓰는 테스트가 없다. 다음 작업에서 피처 테스트가 쓴다.
- App 테스트가 `Tracking`, `FeatureFlags`, `FirebaseRemoteConfig`를 import해도 `testDependencies`는 필요 없다(구현 중 확인. 앱 타깃의 의존성으로 충분하다).
- 헬퍼의 의존 방향 검증은 테스트 타깃이 없으므로 단계 1의 임시 위반 6가지로 확인한다.
- 고쳐야 하는 기존 테스트는 없다. `AppContainerDiagnosticSinkTests`는 그대로 통과해야 한다.

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| `FirebaseAnalyticsCore` 제품의 `import FirebaseAnalytics`가 `enforceExplicitDependencies`에 걸린다 | 중 | 단계 4에서 generate와 build로 먼저 확인한다. 걸리면 `.external` 이름을 조정하고, 안 되면 멈춰서 사용자에게 알린다(IDFA를 수집하는 제품으로 바꾸는 건 사용자 결정이다) |
| 방향 검증이 정당한 기존 의존을 막는다 | 낮 | 단계 1에서 기존 매니페스트 대조표대로 generate가 성공하는지 먼저 확인한다 |
| `fatalError` 출력이 generate 로그에서 읽기 어렵다 | 확인됨 | 문구가 아예 나오지 않는다. 접두사 `[의존 규칙]`을 붙이고, `mayDepend` 주석에 문구를 보는 방법(`xcrun swift ... --tuist-dump` 직접 실행)을 적는다(사용자 결정) |
| Release에서 Firebase를 초기화하면 Analytics가 기본 수집(`first_open`, 세션 등)을 곧바로 시작한다 | 높 | 의도한 동작이다. App Store 개인정보 라벨 갱신이 필요하다는 점을 PR 본문에 적는다 |
| 세션 도중 플래그 값이 한 번 바뀌어 화면과 동작이 어긋난다 | 중 | 사용자가 선택한 방식의 대가다. `FeatureFlags/README.md`에 적고, 플래그를 쓰는 피처가 읽는 시점을 정한다 |
| `feat/module-scaffold-rename` 브랜치를 머지할 때 `Module.swift`가 충돌한다 | 중 | 충돌이 나면 두 변경을 모두 살린다. 스크립트로 만든 Core 모듈은 `mayDepend` 규칙을 따로 더해야 한다는 점을 PR 본문에 적는다 |
| `fetchAndActivate` 상태 enum의 case 이름이 예상과 다르다 | 낮 | 헤더를 읽고 맞춘다. `@unknown default`로 처리한다 |

## 롤백

- 단계마다 커밋이 하나이므로 `git revert`로 되돌린다. 뒤 단계부터 되돌린다(5 → 4 → 3 → 2 → 1). 단계 2와 3의 모듈은 `Module.swift`에 등록되어 있으므로 되돌린 뒤 `mise exec -- tuist generate --no-open`을 다시 돌린다.
- Firebase 제품(단계 4와 5)만 되돌리면 App은 로그 기록기와 기본값 제공자만 쓰게 된다. 패키지 자체(`Tuist/Package.swift`)는 바꾸지 않으므로 `tuist install`이 필요 없다.
- Remote Config가 기기에 남긴 캐시는 앱 동작에 영향이 없다.
- 단계 1만 되돌리면 규칙은 다시 주석으로만 남는다. 단계 2와 3이 `mayDepend`에 줄을 더했으므로 `git revert`가 충돌한다. 충돌이 나면 그 줄까지 포함해 `mayDepend` 전체를 지운다. 모듈 코드는 단계 1에 의존하지 않는다.
