# 클라이언트 진단: request ID, breadcrumbs, 비치명 에러 (Firebase Crashlytics 전송)

## 목표

- **서버에서 난 에러는 서버 로그로 본다.** 클라이언트는 서버가 볼 수 없는 에러만 보고하고, 두 쪽은 request ID로 잇는다.
- **판정, request ID, breadcrumbs, 중복 억제는 직접 만든다.** 전송은 Firebase Crashlytics 어댑터 하나가 맡는다. 크래시 리포팅도 함께 얻는다.
- 모든 API 요청에 `X-Request-ID` 헤더(UUID)가 붙는다. 요청 로그(`os.Logger`)에도 같은 ID가 찍힌다.
- 요청이 끝날 때마다 breadcrumb 한 줄이 남는다. Crashlytics가 켜져 있으면 `Crashlytics.log`로 남으므로 비치명 에러와 크래시 리포트 양쪽에 붙는다.
- Data에서 **보고 대상 에러**가 나면 Crashlytics 비치명 에러(`record(error:userInfo:)`)로 기록한다.
  - 보고 대상은 생성 클라이언트가 던진 에러 중 취소, 오프라인류, 인증 만료를 뺀 나머지다. 예: 연결 실패, 타임아웃, 응답 디코딩 실패. HTTP 4xx/5xx 응답은 서버가 기록하므로 보고하지 않는다.
  - 대시보드에서는 에러가 `operation × 에러 타입 × 코드` 단위로 묶인다(NSError domain과 code 매핑).
  - 같은 에러는 5분에 한 번만 기록한다. 세션당 8개인 Crashlytics 비치명 슬롯이 반복 에러로 밀려나는 것을 막는다.
- **수집 정책: 기본으로 켠다. Debug 빌드는 Firebase를 초기화하지 않는다.** Debug에서는 같은 이벤트와 breadcrumb이 `os.Logger`로만 남는다.
- **`GoogleService-Info.plist`는 아직 없다.** 파일이 없으면 Release에서도 Firebase를 초기화하지 않고, 앱은 크래시 없이 로그 싱크로 동작한다. dSYM 업로드 스크립트도 건너뛴다. 나중에 파일만 넣으면 켜진다(아래 "plist를 넣을 때" 참고).
- `./.claude/scripts/xcbuild.sh test`와 `./.claude/scripts/xcbuild.sh build -configuration Release`가 통과한다.

## 범위 밖

- `GoogleService-Info.plist` 추가와 Firebase 콘솔 설정(프로젝트 생성, App Check, API 키 제한). 사용자가 나중에 넣는다.
- Debug(`.dev`) 환경용 Firebase 앱과 plist를 환경별로 고르는 기능. Debug는 수집하지 않으므로 Release plist 하나만 전제한다.
- 동의 화면과 옵트인. 기본으로 켜는 정책이다(사용자 결정). 대신 개인정보 처리방침과 App Privacy 라벨을 갱신해야 한다. 앱 밖 작업이라 여기서는 체크리스트로만 남긴다.
- `setUserID` 같은 사용자 식별. 쓰는 순간 데이터가 "사용자에 연결됨(linked)"으로 바뀐다.
- Firebase Analytics와 그 밖의 Firebase 제품.
- 서버가 `X-Request-ID`를 기록하거나 되돌려 주게 하는 서버 측 작업.
- `OSLogStore` 로그 내보내기, "문제 신고" 화면.
- 네트워크 밖(Feature, 앱 로직)의 에러 보고와 화면 이동 breadcrumbs.
- 기존 로그 레벨 조정.

## 전제

### 환경
- iOS 17.0, Swift 6 언어 모드(`Tuist/ProjectDescriptionHelpers/AppConstants.swift:23`, `Settings+Common.swift:25`), Xcode 27.
- `Tuist.swift`에서 `enforceExplicitDependencies: true`이다. import하는 외부 모듈은 모두 `.external(name:)`으로 적는다. `import FirebaseCore`를 쓰면 `FirebaseCore`도 따로 적는다.
- `.claude/scripts/xcbuild.sh`는 `tuist install`/`generate`를 하지 않는다. 의존성을 바꾼 단계에서는 `mise exec -- tuist install`을, 파일이나 매니페스트를 바꾼 단계에서는 `mise exec -- tuist generate --no-open`을 먼저 돌린다.
- `xcbuild.sh`는 추가 인자를 xcodebuild에 넘긴다(`xcbuild.sh:80`). Release 빌드는 `xcbuild.sh build -configuration Release`로 확인한다.
- DesignSystem만 기본 격리가 MainActor다(`Settings+Common.swift:49`).
- **`Synchronization.Mutex`는 iOS 18+라 쓸 수 없다.** 동기 락은 `os.OSAllocatedUnfairLock`(iOS 16+)를 쓴다. `@unchecked Sendable`은 쓰지 않는다.
- 환경: Debug는 `BUNDLE_ID_SUFFIX = .dev`, `DEBUG_INFORMATION_FORMAT = dwarf`(`Configurations/Debug.xcconfig:14,35`). Release는 접미사가 없고 `dwarf-with-dsym`이다(`Release.xcconfig:11,32`).
- 앱 테스트(`App/Tests/TuistAppTests.swift`)는 `Bundle.main`을 읽는다. 즉 앱이 테스트 호스트다. 테스트는 Debug로 돌므로 Debug에서 Firebase를 초기화하지 않으면 테스트에도 영향이 없다.

### 모듈 경계 (`Tuist/ProjectDescriptionHelpers/Module.swift`)
- Domain은 Foundation만 import한다(`os` 불가). Networking은 Domain을 모른다. Data → Domain, Networking. 조립은 App이 한다.
- **Firebase는 App 타깃에만 의존시킨다.** 어댑터도 App에 둔다. 모듈은 Firebase를 모른다.
- 테스트 스텁은 `DomainTesting`(`Modules/Core/Domain/Testing/Sources/`)과 `NetworkingTesting`에 둔다.

### swift-openapi-runtime 동작 (1.12.1, `UniversalClient.swift:88-191`에서 확인)
- 순서는 serializer → 미들웨어 체인(transport 포함) → **deserializer**다. 응답 디코딩 실패는 미들웨어에 보이지 않고 Data의 호출부에서만 잡힌다.
- 호출부가 받는 에러는 늘 `ClientError`(`operationID`, `request`, `response`, `underlyingError`, `causeDescription`)다.
  - `ClientError.request`는 미들웨어가 붙이기 **전**의 요청이다.
  - `ClientError.response`는 가장 바깥 미들웨어가 돌려준 응답이다. 디코딩 실패일 때만 값이 있다.
- 그래서 `RequestIDMiddleware`는 응답 헤더에도 같은 ID를 넣는다. 전송 실패는 응답이 없으므로 이벤트에 request ID가 없다. 대신 breadcrumb에 남는다.
- `causeDescription`과 에러 설명에는 URL(쿼리 포함)이 들어갈 수 있다. 보고에 넣지 않는다.

### Firebase Crashlytics (조사 결과, firebase-ios-sdk 12.19.2, 2026-09-15)
- SPM product는 `FirebaseCrashlytics` 하나다. Analytics는 필요 없다. FirebaseSessions와 FirebaseInstallations가 함께 따라온다. 요구 조건은 iOS 15+, Xcode 26.2+, Swift 6.2.3+이다. **12.11.0 미만은 쓰지 않는다**(초기화 직후 호출이 조용히 버려지던 버그).
- API:

  | API | 도입 | 용도 |
  |---|---|---|
  | `FirebaseApp.configure()` | FirebaseCore | 초기화. **메인 스레드**에서 부른다. plist가 없으면 NSException으로 크래시한다 |
  | `Crashlytics.crashlytics()` | 7.0 | 인스턴스 |
  | `record(error:userInfo:)` | 9.2.0 | 비치명 에러 |
  | `log(_:)` | 7.0 | breadcrumb |
  | `setCrashlyticsCollectionEnabled(_:)` | 7.0 | 이번에는 쓰지 않는다 |

  출처: `FIRCrashlytics.h`(12.19.2), https://firebase.google.com/docs/crashlytics/ios/customize-crash-reports
- **`FIRCrashlytics`는 Sendable로 선언돼 있지 않다.** 인스턴스를 저장하거나 액터 경계 너머로 넘기지 말고, 호출할 때마다 `Crashlytics.crashlytics()`를 받는다. 스레드 안전성은 공식 문서에 명시가 없다(미확인). 계획은 백그라운드 호출을 전제로 한다. 위험 요소 참고.
- 한도: 비치명 에러는 세션당 최근 8개, 로그는 세션당 64KB(넘치면 오래된 것부터 지움), custom key는 64쌍, 쌍당 1KB다. 비치명 에러는 **다음 실행 때** 전송된다. 그룹핑은 NSError의 domain+code 기준이다.
- Tuist 통합:
  - `Tuist/Package.swift:14-20`에 `.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.19.2")`를 넣는다(13 미만).
  - `productTypes`는 기본(정적)을 쓴다. `-[FBLPromise ...] unrecognized selector`가 나면 `"FBLPromises": .framework`로 바꾼다(Tuist 공식 팁).
  - 앱 타깃에 `OTHER_LDFLAGS = $(inherited) -ObjC`를 넣는다. 중복 심볼 오류 보고가 있다(tuist#6243).
  - 앱 타깃의 `ENABLE_USER_SCRIPT_SANDBOXING = NO`. dSYM 스크립트가 checkouts 경로를 읽기 때문이다.
  - dSYM 스크립트 경로는 `$SRCROOT/../Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run`이다. 공식 문서의 `SourcePackages` 경로는 Tuist에 없다. 입력 목록은 SDK의 `Crashlytics/CrashlyticsInputFiles.xcfilelist`이다.
- `GoogleService-Info.plist`는 비밀이 아니다(Firebase 보안 체크리스트). 커밋해도 된다. 방어는 App Check와 키 제한이 맡는다(`Configurations/ClientKeys.xcconfig.example`의 방침과 같다). `App/Resources/`에 두면 `Resources/**`(`Project+Templates.swift:177`)로 번들에 들어간다.
- Privacy Manifest는 SDK에 들어 있다. Crashlytics는 CrashData와 OtherDiagnosticData를 선언한다(사용자에 연결되지 않음, 추적 아님, AppFunctionality). App Store 라벨은 앱이 직접 판단해 선언한다.

### 변경 지점
- `Modules/Core/DesignSystem/Sources/Views/AsyncTaskRunner.swift:83`: `Logger(subsystem: "DesignSystem", category: "AsyncButton")`.
- `Modules/Core/Networking/Sources/Middleware/LoggingMiddleware.swift:14-61`: `init(subsystem:)`, `intercept`, `static func summary(of:)`.
- `Modules/Core/Networking/Sources/APIClientFactory.swift:24-53`: `make(...)`. refresh 클라이언트는 `[logging]`, 본 클라이언트는 `[logging, Retry, Auth]`이다.
- `Modules/Core/Networking/Sources/NetworkDefaults.swift`: 네트워크 상수.
- `Modules/Core/Networking/README.md:39-45`: `make` 예시와 미들웨어 설명.
- `Modules/Core/Data/Sources/RemoteItemRepository.swift:19-40`: `catch`에서 모든 에러를 `.unavailable`로 바꾼다. 여기가 보고 지점이다.
- `Modules/Core/Data/Tests/RemoteItemRepositoryTests.swift`: 생성부.
- `App/Sources/DI/AppContainer.swift:23-46`: 조립부, `LogCategory`. `AppContainer`는 `TuistAppApp`의 저장 프로퍼티라서 **`didFinishLaunching`보다 먼저** 만들어진다(`App/Sources/TuistAppApp.swift:12`). 메인 액터다.
- `App/Project.swift:15-23`: 앱 의존성.
- `Tuist/ProjectDescriptionHelpers/Project+Templates.swift:160-182`: `Project.app(...)` 템플릿. 타깃 settings와 scripts를 받을 자리가 없다.
- `Tuist/ProjectDescriptionHelpers/Settings+Common.swift:76`, `Configurations/ClientKeys.xcconfig.example:44-47`: Sentry용 자리 `CRASH_REPORTING_DSN`. 코드에서 읽는 곳은 없다(grep으로 확인).
- 기존 로거 주입 패턴: `TokenRefresher.init(..., logger: Logger = Logger(.disabled))`(`Modules/Core/Networking/Sources/Auth/TokenRefresher.swift:31-41`).

## 결정 사항

| 결정 | 선택 | 이유 |
|---|---|---|
| 기본 원칙 | 서버 에러는 서버 로그가 맡는다. 클라이언트는 서버가 볼 수 없는 에러만 보고하고, request ID로 잇는다 | 중복과 개인정보 노출면을 줄인다(사용자 합의) |
| 전송 수단 | Firebase Crashlytics. 판정, ID, breadcrumbs, 중복 억제는 직접 만든다 | 사용자 결정. 크래시 리포팅, 대기열, 재전송, 대시보드를 얻는다 |
| breadcrumb 저장 | 직접 만든 메모리 버퍼 대신 싱크로 흘려보낸다. Crashlytics 싱크는 `log(_:)`를 부른다 | Crashlytics 로그는 비치명 에러와 **크래시 리포트 양쪽에** 붙는다. 메모리 버퍼는 크래시 때 사라진다 |
| 수집 정책 | 기본으로 켠다. Debug는 Firebase를 초기화하지 않고 로그 싱크를 쓴다 | 사용자 결정. Debug에서는 시끄럽고 dSYM도 없다. 테스트 호스트 문제도 함께 피한다 |
| 초기화 위치 | `AppContainer.init` 맨 앞에서 `FirebaseBootstrap.configureIfAvailable()`를 부른다 | `AppContainer`가 `didFinishLaunching`보다 먼저 만들어지고 메인 액터에서 돈다. 초기화 결과로 싱크를 고르는 조립 지점과 같은 곳에 있어야 순서가 보장된다 |
| 초기화 조건 | `!DEBUG && plist가 번들에 있음`일 때만 초기화한다. 판정은 `static func decision(isDebug:hasConfigFile:) -> Decision`으로 분리한다 | plist가 없으면 `configure()`가 크래시한다. 파일을 넣기 전에도 Release가 돌아야 한다 |
| 싱크 선택 | 초기화되면 `CrashlyticsDiagnosticSink`, 아니면 `LoggerDiagnosticSink`(`os.Logger`, category `Diagnostics`) | Debug에서도 무엇이 보고될지 Console에서 볼 수 있다. plist가 없을 때 확인하는 수단이기도 하다 |
| Firebase 위치 | App 타깃만 의존한다. 어댑터는 `App/Sources/Diagnostics/`에 둔다 | 조립 지점만 구현을 안다는 기존 원칙을 따른다. 모듈 빌드에 Firebase가 끼지 않는다 |
| NSError 매핑 | domain `"network.<operationID>.<errorType>"`, code는 `URLError` 코드(없으면 0). userInfo에는 `summary`, `requestID`(있을 때)를 넣는다. 매핑은 `static func nsError(for:)`로 분리해 테스트한다 | Crashlytics가 domain+code로 묶는다. operation과 에러 종류별로 이슈가 나뉘게 한다. Swift `hashValue`처럼 실행마다 바뀌는 값은 쓰지 않는다 |
| 보고 지점 | Data(`RemoteItemRepository`의 `catch`) 하나 | 디코딩 실패는 미들웨어에 보이지 않는다(전제 참고) |
| 보고 대상 판정 | Networking의 공개 함수 `NetworkFailure.describe(_:)`. 제외 대상은 `CancellationError`, `URLError`의 `.cancelled`/`.notConnectedToInternet`/`.networkConnectionLost`/`.dataNotAllowed`/`.internationalRoamingOff`, `AuthenticationError` | 에러 타입을 아는 곳은 Networking이다. `LoggingMiddleware.summary`도 이 함수로 옮겨서 판정과 요약을 한 곳에 둔다 |
| request ID | `RequestIDMiddleware`를 가장 바깥에 둔다. 요청 헤더가 없을 때 UUID를 넣고, 응답 헤더가 없을 때 같은 값을 넣는다 | Logging이 ID를 보고, 재시도는 같은 ID를 공유한다. 응답에 넣는 건 `ClientError.response`에서 Data가 ID를 읽기 위해서다 |
| 헤더 이름 | `X-Request-ID` (`NetworkDefaults.requestIDField`) | 사실상 표준이다. 서버와 다르게 정해지면 상수 하나만 바꾼다 |
| breadcrumb 수집 | `LoggingMiddleware`가 요청을 끝낼 때 `NetworkActivityObserving.requestFinished(_:)`(동기)를 부른다. App 어댑터가 이를 `Breadcrumb`로 바꿔 `BreadcrumbRecording`에 넘긴다 | Networking은 Domain을 모른다. 동기 호출이라 순서가 지켜진다 |
| breadcrumb 내용 | `"GET /items 200 123ms rid=…"`: method, 쿼리를 뺀 path, status 또는 실패 요약, 소요 시간, request ID | 기존 로그 규칙(헤더·바디·쿼리 제외)과 같다 |
| 중복 억제 | Domain `DiagnosticReporter`(actor). fingerprint(`operationID + errorType + errorCode`)별로 5분. `nonisolated func report(_:)`가 `Task`로 넘긴다 | 비치명 슬롯(세션당 8개)을 지킨다. Data의 `catch`가 기다리지 않게 한다. 스텁으로 테스트할 수 있다 |
| 싱크 프로토콜 | Domain에 `DiagnosticEventSink.send(_:)`(동기, non-throwing)와 `BreadcrumbRecording.record(_:)`(동기)를 둔다 | Crashlytics 호출은 실패를 돌려주지 않는다. 전송 수단을 바꿔도 Domain과 Data는 그대로다 |
| 앱 정보(버전, OS) | 따로 모으지 않는다 | Crashlytics가 자동으로 붙인다 |
| 로거 주입 | `os.Logger` 값을 그대로 주입(래퍼 없음) | privacy 지정과 컴파일 타임 최적화를 지킨다. `swift.md`의 "프로토콜에 의존" 규칙에 대한 의도된 예외이고, 기존 `TokenRefresher` 패턴과 같다(사용자 결정) |
| DesignSystem subsystem | `Bundle.main.bundleIdentifier` | 모든 로그의 subsystem을 앱 번들 ID로 맞춘다 |
| 앱 템플릿 | `Project.app(...)`에 `targetSettings: SettingsDictionary = [:]`와 `scripts: [TargetScript] = []` 매개변수를 추가한다. 값은 `App/Project.swift`가 넘긴다 | `-ObjC`와 샌드박싱 해제를 공통 설정에 넣으면 모든 모듈로 퍼진다. 앱에만 필요하다 |
| dSYM 스크립트 | `Scripts/crashlytics-upload-symbols.sh` 래퍼. `CONFIGURATION != Release`이거나 plist가 없으면 경고만 내고 `exit 0`으로 끝난다. 아니면 SDK의 `run`을 실행한다 | plist가 없을 때 Release 빌드가 깨지지 않게 한다. Debug에는 dSYM이 없다 |
| `CRASH_REPORTING_DSN` | `InfoPlist.runnable`과 `.example`에서 지운다 | Sentry용 자리였고, 읽는 코드가 없다 |
| 수치 | 중복 억제 5분 | `DiagnosticDefaults` enum에 둔다. 생성자 인자로 덮어쓸 수 있다 |
| 워크스페이스 스킴 (구현 중 추가) | Tuist 자동 생성 워크스페이스 스킴을 끄고(`autogeneratedWorkspaceSchemes: .disabled`) `Scheme.workspace()`로 직접 정의한다. 빌드 액션은 앱·모듈 구현·데모 앱, 테스트 액션은 모든 `*Tests`. 모듈 목록은 `Module.all`/`Module.withDemoApp` 등록부에서 읽고, 템플릿이 매니페스트 선언과 등록부가 어긋나면 생성을 멈춘다 | 자동 생성 스킴은 테스트 타깃과 외부 타깃까지 `buildForRunning`으로 넣는다. Release는 `ENABLE_TESTABILITY = NO`라 `@testable` 테스트 타깃이 모두 실패해 `xcbuild.sh build -configuration Release`가 이 작업 전부터 깨져 있었다. 앱 스킴만 Release로 빌드하는 우회는 데모 앱을 빼고 원인을 남기므로 택하지 않았다(사용자 결정) |

## 변경 계획

각 단계는 독립적으로 빌드와 테스트가 통과하고, 커밋 하나 분량이다. 작업 브랜치(예: `feat/diagnostics-crashlytics`)에서 진행한다.

### 1. DesignSystem 로그 subsystem 통일
- 파일: `Modules/Core/DesignSystem/Sources/Views/AsyncTaskRunner.swift`
- 변경: `Diagnostics.logger`의 subsystem을 `Bundle.main.bundleIdentifier ?? Diagnostics.fallbackSubsystem`으로 바꾼다. category 리터럴은 `Diagnostics.category` 상수로 뺀다.
- 검증: `xcbuild.sh build`. `grep -rn 'subsystem: "' Modules App` 결과가 0건이다.

### 2. Networking: 실패 판정을 공개 함수로 분리
- 파일: `Modules/Core/Networking/Sources/Diagnostics/NetworkFailure.swift`(새 파일), `LoggingMiddleware.swift`, `Tests/NetworkFailureTests.swift`(새 파일), `Tests/LoggingMiddlewareTests.swift`
- 변경:
  - `public struct NetworkFailure: Sendable, Equatable`. 필드는 `operationID: String?`, `errorType: String`(타입 이름. 연관값이 있는 enum이면 `.case이름`을 붙인다, 리뷰 R1-2), `errorCode: Int?`(`URLError` 코드), `summary: String`(기존 규칙: `URLError(-1004)` 또는 타입 이름. case 이름은 붙이지 않는다), `requestID: String?`, `isReportable: Bool`, `isCancellation: Bool`(리뷰 R1-4).
  - `public static func describe(_ error: any Error) -> NetworkFailure`.
    - `ClientError`면 `underlyingError`와 `operationID`를 쓴다.
    - `requestID`는 `clientError.response?.headerFields[NetworkDefaults.requestIDField]`에서 읽는다. 필드는 3단계에서 추가하므로 이 단계에서는 늘 `nil`이다.
  - `LoggingMiddleware.summary(of:)`는 `describe(_:).summary`를 쓰도록 바꾼다. 기존 테스트의 기대값은 그대로 둔다.
    (리뷰 R2-1: 미들웨어가 `describe`를 직접 부르게 되어 `summary(of:)`를 지웠다. 요약 규칙 테스트는 `NetworkFailureTests`로 옮겼다.)
- 검증: `NetworkingTests` 전체 통과.

### 3. Networking: RequestIDMiddleware
- 파일: `Modules/Core/Networking/Sources/Middleware/RequestIDMiddleware.swift`(새 파일), `NetworkDefaults.swift`, `LoggingMiddleware.swift`, `APIClientFactory.swift`, `README.md`, `Tests/RequestIDMiddlewareTests.swift`(새 파일)
- 변경:
  - `NetworkDefaults.requestIDField: HTTPField.Name`(`"X-Request-ID"`).
  - `struct RequestIDMiddleware: ClientMiddleware`, `init(makeID: @escaping @Sendable () -> String = { UUID().uuidString })`.
    - 요청에 헤더가 없으면 넣는다.
    - 응답에 헤더가 없으면 같은 값을 넣는다.
    - 에러는 그대로 다시 던진다.
    - 문서 주석에 "응답 헤더의 값은 클라이언트가 넣은 것일 수 있다"고 적는다.
  - `LoggingMiddleware`는 요청 헤더에서 ID를 읽어 `rid=<id>`를 남긴다(`privacy: .public`, 무작위 UUID). 없으면 `-`를 남긴다.
  - `APIClientFactory.make`: 본 클라이언트는 `[requestID, logging, Retry, Auth]`, refresh 클라이언트는 `[requestID, logging]`으로 둔다. 순서 주석과 README를 고친다.
- 검증: `NetworkingTests` 전체 통과.

### 4. Networking: 요청 활동 옵저버
- 파일: `Modules/Core/Networking/Sources/Diagnostics/NetworkActivityObserving.swift`, `NetworkRequestRecord.swift`(새 파일), `LoggingMiddleware.swift`, `APIClientFactory.swift`, `README.md`, `Modules/Core/Networking/Testing/Sources/RecordingNetworkActivityObserver.swift`(새 파일), `App/Sources/DI/AppContainer.swift`(호출부만)
- 변경:
  - `public protocol NetworkActivityObserving: Sendable { func requestFinished(_ record: NetworkRequestRecord) }`.
  - `public struct NetworkRequestRecord: Sendable, Equatable`. 필드는 `method`, `path`(쿼리 제외), `statusCode: Int?`, `failureSummary: String?`, `isCancellation: Bool`(리뷰 R1-4. 취소는 로그 `info`, breadcrumb `.info`), `elapsedMilliseconds: Int64`, `requestID: String?`.
  - `LoggingMiddleware.init(subsystem:observer:)`. 로그를 남긴 **뒤** 성공과 실패 모두에서 `observer.requestFinished`를 부른다.
  - `APIClientFactory.make`에 `activityObserver: any NetworkActivityObserving` 인자를 추가한다.
  - App 호출부는 이 단계에서 `AppContainer.swift` 안의 private no-op 옵저버를 넘긴다. 6단계에서 지운다.
  - `RecordingNetworkActivityObserver`는 `OSAllocatedUnfairLock`로 기록한다.
- 검증: `NetworkingTests` 전체 통과, `xcbuild.sh build` 통과.

### 5. Domain: 진단 타입과 Reporter
- 파일(각각 새 파일, `Modules/Core/Domain/Sources/Diagnostics/` 아래):
  - `Breadcrumb.swift`: `struct`(`category`, `message`, `level: BreadcrumbLevel`), `Sendable`, `Equatable`
  - `BreadcrumbLevel.swift`: `enum`(`info`, `error`)
  - `DiagnosticFailure.swift`: `struct`(`operationID: String?`, `errorType`, `errorCode: Int?`, `summary`, `requestID: String?`)와 `var fingerprint: String`
  - `BreadcrumbRecording.swift`: `protocol BreadcrumbRecording: Sendable { func record(_ breadcrumb: Breadcrumb) }`
  - `DiagnosticEventSink.swift`: `protocol DiagnosticEventSink: Sendable { func send(_ failure: DiagnosticFailure) }`. 문서 주석에 "전송 수단(Crashlytics 등)을 바꾸는 경계"라고 적는다.
  - `DiagnosticReporting.swift`: `protocol DiagnosticReporting: Sendable { func report(_ failure: DiagnosticFailure) }`(동기, 결과를 기다리지 않음)
  - `DiagnosticReporter.swift`: `public actor DiagnosticReporter: DiagnosticReporting`
    - `init(sink:now:dedupeInterval:)`
    - `nonisolated func report(_:)`는 `Task { await handle(failure) }`를 실행한다.
    - `func handle(_:) async -> Bool`(보냈으면 `true`)은 `internal`로 두고 `@testable import`로 테스트한다.
  - `DiagnosticDefaults.swift`: `enum`(5분)
  - `Modules/Core/Domain/Testing/Sources/`: `SpyDiagnosticEventSink`, `SpyBreadcrumbRecorder`, `SpyDiagnosticReporter`. 셋 다 동기 호출을 기록해야 하므로 `OSAllocatedUnfairLock`를 쓴다. "Foundation만" 규칙은 Domain 본체에만 적용되고 Testing 타깃은 `os`를 써도 된다고 본다. 시스템 프레임워크 import가 명시적 의존성 검사에 걸리는지는 **구현 중 확인**한다.
- `DomainTests.swift`의 "Domain은 선언뿐" 주석을 고친다.
- 검증: `xcbuild.sh test -only-testing:DomainTests/DiagnosticReporterTests` 통과.

### 6. App: 로그 싱크와 breadcrumb 조립 (Firebase 없이)
- 파일: `App/Sources/Diagnostics/LoggerDiagnosticSink.swift`, `App/Sources/Diagnostics/NetworkBreadcrumbAdapter.swift`(새 파일), `App/Sources/DI/AppContainer.swift`, `App/Tests/NetworkBreadcrumbAdapterTests.swift`(새 파일)
- 변경:
  - `LoggerDiagnosticSink: DiagnosticEventSink, BreadcrumbRecording`(`os.Logger` 주입). breadcrumb은 `.info`/`.error`로, 이벤트는 `.error`로 남긴다. 모든 필드가 요약값이라 `.public`으로 남긴다.
  - `NetworkBreadcrumbAdapter: NetworkActivityObserving`(`BreadcrumbRecording` 주입). 변환은 `static func breadcrumb(from:) -> Breadcrumb`로 분리한다. category는 상수 `"network"`이고, 실패면 level이 `.error`다.
  - `AppContainer`는 `LoggerDiagnosticSink`, `DiagnosticReporter(sink:)`, 어댑터를 만든다. 어댑터는 `activityObserver`로 넘기고, 4단계의 no-op은 지운다. reporter는 8단계에서 쓸 프로퍼티로 보관한다. `LogCategory.diagnostics`를 추가하고, 상단 주석의 구현 타입 목록을 갱신한다.
- 검증: `xcbuild.sh test` 전체 통과. Debug로 실행해 Console에 breadcrumb 로그(`rid=` 포함)가 찍히는지 본다.

### 7. Data: RemoteItemRepository에서 보고
- 파일: `Modules/Core/Data/Sources/RemoteItemRepository.swift`, `Modules/Core/Data/Tests/RemoteItemRepositoryTests.swift`, `Modules/Core/Data/Project.swift`(테스트 의존성에 `.testing(.domain)`이 없으면 추가), `App/Sources/DI/AppContainer.swift`
- 변경:
  - `init(client:reporter: any DiagnosticReporting)`.
  - `catch`에서 `NetworkFailure.describe(error)`를 구하고, `isReportable`이면 `reporter.report(DiagnosticFailure(...))`를 부른다. 그다음 기존처럼 `.unavailable`을 던진다.
  - `.unauthorized`/`.undocumented`는 보고하지 않는다(서버가 본다). 코드 주석으로 이유를 남긴다.
  - 문서 주석에 "생성 클라이언트를 부르는 catch에서 보고한다"는 규칙을 적는다(새 Repository도 따르게).
  - App은 6단계의 reporter를 넘긴다.
- 검증: `xcbuild.sh test` 전체 통과. Debug로 실행해 개발 서버가 없는 상태에서 목록을 불러오면 Console에 이벤트 로그가 한 번 찍히고, 5분 안에 다시 시도하면 찍히지 않는지 본다.

### 8. Firebase 의존성과 빌드 설정
- 파일: `Tuist/Package.swift`, `Tuist/Package.resolved`, `App/Project.swift`, `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`, `Tuist/ProjectDescriptionHelpers/Settings+Common.swift`, `Configurations/ClientKeys.xcconfig.example`, `Scripts/crashlytics-upload-symbols.sh`(새 파일, 실행 권한)
- 추가 파일(구현 중 추가, 결정 사항 "워크스페이스 스킴"): `Workspace.swift`, `Tuist/ProjectDescriptionHelpers/Scheme+Workspace.swift`(새 파일), `Tuist/ProjectDescriptionHelpers/Module.swift`, `.claude/scripts/xcbuild.sh`(주석만)
- 변경:
  - `Package.swift`에 firebase-ios-sdk `from: "12.19.2"`를 추가하고 주석으로 용도를 적는다.
  - `App/Project.swift`에 `.external(name: "FirebaseCrashlytics")`, `.external(name: "FirebaseCore")`를 추가한다. `targetSettings: ["OTHER_LDFLAGS": "$(inherited) -ObjC", "ENABLE_USER_SCRIPT_SANDBOXING": "NO"]`와 `scripts: [.post(script 경로, name: "Upload Crashlytics dSYM", inputFileListPaths: [SDK xcfilelist], basedOnDependencyAnalysis: false)]`를 넘긴다. 이유는 주석으로 남긴다.
  - `Project.app(...)`에 `targetSettings`와 `scripts` 매개변수를 추가한다. `.settings(base: targetSettings)`로 앱 타깃에만 적용한다. 공통 xcconfig와 키가 겹치지 않는지 확인한다.
  - 래퍼 스크립트는 `CONFIGURATION`이 `Release`가 아니거나 `${SRCROOT}/Resources/GoogleService-Info.plist`가 없으면 `echo "warning: ..."` 후 `exit 0`한다. 아니면 `"${SRCROOT}/../Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run"`을 `exec`한다. 경로가 없으면 `error:`로 실패한다.
  - `CRASH_REPORTING_DSN`을 `Settings+Common.swift:76`과 `.example`에서 지운다. 로컬 `ClientKeys.xcconfig`에 남은 값은 무해하다.
  - `mise exec -- tuist install` 후 `tuist generate --no-open`을 돌린다.
- 검증: `xcbuild.sh build`(Debug), `xcbuild.sh build -configuration Release`가 통과한다. Release 빌드 로그에 "GoogleService-Info.plist 없음" 경고가 찍힌다. `-ObjC` 중복 심볼 오류와 FBLPromises 문제가 없는지 본다. 문제가 나면 전제의 대응을 적용하고 이 문서에 기록한다.
- 결과: `-ObjC` 중복 심볼 없음. FBLPromises는 Firebase를 초기화해야 드러나므로 plist를 넣을 때 확인한다. Release 빌드는 처음에 테스트 타깃의 `@testable import`에서 실패했다(기존 문제, 결정 사항 "워크스페이스 스킴"). 스킴을 직접 정의한 뒤 Debug·Release 빌드와 전체 테스트(7개 번들)가 통과한다.

### 9. App: Firebase 초기화와 Crashlytics 싱크
- 파일: `App/Sources/Diagnostics/FirebaseBootstrap.swift`, `App/Sources/Diagnostics/CrashlyticsDiagnosticSink.swift`(새 파일), `App/Sources/DI/AppContainer.swift`, `App/Tests/FirebaseBootstrapTests.swift`, `App/Tests/CrashlyticsDiagnosticSinkTests.swift`(새 파일)
- 변경:
  - `FirebaseBootstrap`:
    - `enum Decision { case configure, skipDebug, skipMissingConfigFile }`
    - `static func decision(isDebug:hasConfigFile:) -> Decision`
    - `@MainActor static func configureIfAvailable(bundle: Bundle = .main) -> Decision`: `#if DEBUG`로 `isDebug`를 구하고, `bundle.path(forResource:ofType:)`로 plist가 있는지 확인한다. 리소스 이름은 상수로 둔다. `.configure`면 `FirebaseApp.configure()`를 부른다. 내린 결정을 돌려주어 호출부가 건너뛴 이유를 로그로 남기게 한다(구현 중 `Bool`에서 바꿈).
  - `CrashlyticsDiagnosticSink: DiagnosticEventSink, BreadcrumbRecording`. 저장 프로퍼티 없이 호출할 때마다 `Crashlytics.crashlytics()`를 받는다(non-Sendable이라서).
    - `record(_:)`는 `log("[\(category)] \(message)")`를 부른다.
    - `send(_:)`는 `record(error: Self.nsError(for:), userInfo:)`를 부른다.
    - `static func nsError(for:) -> NSError`는 결정 사항의 매핑이다. domain 접두사와 userInfo 키는 `private enum`에 둔다.
  - `AppContainer.init`은 맨 앞에서 `FirebaseBootstrap.configureIfAvailable()`를 부른다. 결과에 따라 싱크를 고르고, 건너뛰었으면 이유를 `notice`로 남긴다.
- 검증: `xcbuild.sh test` 전체 통과(Debug라 초기화하지 않는다). `xcbuild.sh build -configuration Release` 통과. Release 빌드를 시뮬레이터에서 실행해 plist 없이 크래시하지 않고, "Firebase 초기화 건너뜀(설정 파일 없음)" 로그가 찍히는지 본다.

## 테스트 전략

- **NetworkingTests/NetworkFailureTests** (새 파일)
  - `isReportable == false`: `CancellationError`, 제외 대상 `URLError` 5종, `AuthenticationError`, 그리고 이것들을 `ClientError`로 감싼 경우.
  - `isReportable == true`: `URLError(.cannotConnectToHost)`, `URLError(.timedOut)`, `DecodingError`를 담은 `ClientError`.
  - `errorType`과 `errorCode`: `URLError`는 코드가 있고, `DecodingError`는 `nil`이다.
  - `summary`는 기존 기대값을 유지한다.
  - `requestID`는 `response` 헤더에서 읽고, `response == nil`이면 `nil`이다. `operationID`를 전달하는지 본다.
- **NetworkingTests/RequestIDMiddlewareTests** (새 파일, 고정 `makeID`)
  - 헤더가 없으면 요청에 붙는다. 이미 있으면 유지된다.
  - 응답에 헤더가 없으면 같은 ID가 붙는다. 있으면 유지된다.
  - 에러는 그대로 다시 던져진다.
- **NetworkingTests/LoggingMiddlewareTests** (추가): 성공하면 status와 request ID가 담긴 기록 하나, 실패하면 `failureSummary`가 담긴 기록 하나와 에러 재전파. path에는 쿼리가 없다.
- **NetworkingTests/APIClientFactoryTests**: `make`를 직접 부르면 새 인자를 넘긴다(**구현 중 확인**, grep상 직접 호출은 없다).
- **DomainTests/DiagnosticReporterTests** (새 파일, 스파이 싱크와 고정 시계)
  - 첫 보고는 싱크에 그대로 전달된다.
  - 같은 fingerprint는 5분 안이면 억제되고, 지나면 다시 전달된다.
  - fingerprint가 다르면 각각 전달된다.
  - 동시에 `handle`해도 같은 fingerprint는 한 번만 전달된다.
- **DomainTests/DiagnosticFailureTests**: fingerprint가 operation, 타입, 코드로만 정해진다(summary와 requestID가 달라도 같다).
- **DataTests/RemoteItemRepositoryTests** (수정·추가, `SpyDiagnosticReporter`)
  - 보고 대상 전송 실패는 보고 한 번과 `.unavailable`로 끝난다.
  - 취소와 오프라인은 보고하지 않는다.
  - `.undocumented`는 보고하지 않는다.
  - 성공하면 보고하지 않는다.
- **TuistAppTests/NetworkBreadcrumbAdapterTests**: 성공과 실패 기록을 message와 level로 바꾼다. request ID가 없으면 `rid=-`다.
- **TuistAppTests/FirebaseBootstrapTests**: `decision`의 네 조합(Debug/Release × 파일 있음/없음).
- **TuistAppTests/CrashlyticsDiagnosticSinkTests**: `nsError(for:)`의 domain, code(`URLError` 코드와 없을 때 0), userInfo(`requestID`가 `nil`이면 키가 없음). Crashlytics 호출 자체는 테스트하지 않는다(Debug에서는 초기화하지 않는다).

## 위험 요소

| 위험 | 가능성 | 대응 |
|---|---|---|
| `Crashlytics`를 백그라운드 스레드에서 불러도 되는지 공식 명시가 없음 | 저 | 흔히 쓰는 방식이고, CHANGELOG에 내부 큐 관련 수정 기록이 있다. 문제가 보이면 싱크 호출을 메인 액터로 옮긴다(`Task { @MainActor in ... }`, breadcrumb 순서 영향은 감수한다) |
| `-ObjC`로 인한 중복 심볼, 또는 FBLPromises 셀렉터 크래시 | 중 | 8단계에서 Release까지 빌드하고 실행해 확인한다. 셀렉터 문제면 `productTypes`에 `"FBLPromises": .framework`를 적용한다 |
| plist를 넣었는데 번들 ID가 맞지 않거나 파일이 잘못돼 `configure()`가 크래시 | 중 | 존재 여부만 검사하므로 내용 오류는 막지 못한다. "plist를 넣을 때" 체크리스트에서 Release 실행으로 확인한다 |
| 개인정보 처리방침과 App Privacy 라벨을 갱신하지 않음 | 중 | 기본으로 켜는 정책의 전제 조건이다. 출시 전 체크리스트(아래)에 넣는다 |
| breadcrumb path에 리소스 ID가 남음(`/items/42`) | 중 | 지금 명세의 경로에는 ID가 없다. 개인정보가 들어간 경로가 생기면 operation ID로 바꾼다 |
| 서버가 `X-Request-ID`를 기록하지 않아 이을 수 없음 | 중 | 서버 측 합의가 필요하다(범위 밖) |
| 전송 실패 이벤트에 request ID가 없음 | 확실 | 의도한 동작이다. 서버가 받지 못한 요청이다. breadcrumb에는 ID가 남는다 |
| 비치명 슬롯(세션당 8개) 초과로 오래된 기록이 유실됨 | 저 | fingerprint별 5분 억제로 줄인다 |
| 보고 지점이 `RemoteItemRepository` 하나라 새 Repository에서 빠짐 | 중 | 문서 주석에 규칙을 적는다. 세 곳 이상이 되면 공용 헬퍼로 뺀다 |
| 새 모듈을 `Module.all`에 등록하지 않아 워크스페이스 스킴에서 빠짐 | 저 | `Project.core`/`Project.feature`가 등록부에 없는 모듈이나 `hasDemoApp` 불일치를 만나면 생성을 멈춘다 |
| FirebaseSessions와 Installations가 추가로 수집함 | 저 | SDK Privacy Manifest에 선언돼 있다. 라벨 판단 때 함께 본다. `FirebaseDataCollectionDefaultEnabled` 적용 여부는 미확인이다 |

## plist를 넣을 때 (후속 작업 체크리스트)

1. Firebase 콘솔에서 번들 ID `com.olivebridge.tuistapp`로 iOS 앱을 등록한다. App Check를 켜고 API 키 제한을 건다.
2. `GoogleService-Info.plist`를 `App/Resources/`에 넣고 커밋한다.
3. `xcbuild.sh build -configuration Release`를 돌려 dSYM 업로드 스크립트가 실행되는지(경고가 사라지는지) 본다.
4. Release 빌드를 디버거 없이 실행하고 보고 대상 실패를 일으킨다. 앱을 다시 실행한 뒤 Crashlytics 대시보드의 비치명 에러와 로그 탭에서 breadcrumb을 확인한다. 필요하면 `-FIRDebugEnabled` 실행 인자로 "Completed report submission"을 확인한다.
5. 개인정보 처리방침과 App Store Connect App Privacy에 Crash Data와 기타 진단 데이터(사용자에 연결되지 않음, 추적 아님)를 선언한다.

## 롤백

- 단계마다 커밋이 하나씩이므로 역순으로 `git revert`한다.
- 9단계를 되돌리면 항상 로그 싱크로 동작한다. 8단계를 되돌리면 Firebase 의존성, 빌드 설정, 스크립트가 빠진다(9단계를 먼저 되돌린다).
- 7단계를 되돌리면 보고가 멈춘다. 6단계를 되돌리면 옵저버가 no-op으로 돌아간다. 둘 다 네트워크 동작에는 영향이 없다.
- 3단계(RequestID)는 헤더 하나를 더하는 것뿐이다. 되돌려도 뒤 단계는 `requestID == nil`로 동작한다.
- 이미 배포한 빌드의 수집을 원격으로 끄는 스위치는 이번 범위에 없다. 필요해지면 `setCrashlyticsCollectionEnabled`와 원격 설정을 다음 작업에서 다룬다.
