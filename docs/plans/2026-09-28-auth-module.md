# Auth 모듈 분리와 세션 API

## 목표

- 토큰 모델·저장소·갱신·세션 상태가 새 Core 모듈 `Auth` 에 있고, `Networking` 은 `Auth` 의 public API 만 써서
  헤더 주입과 401 갱신을 한다. `Auth` 는 OpenAPIRuntime·생성 클라이언트를 import 하지 않는다.
- Domain 에 `AuthRepository`(로그인·로그아웃·세션 상태 스트림)가 있고 Data 의 `RemoteAuthRepository` 가 명세의
  `login` operation 과 `Auth` 로 구현한다. App 의 `AppContainer` 가 이를 조립해 `authRepository` 로 노출한다.
- 로그인·로그아웃이 진행 중인 토큰 갱신과 섞여도 이전 세션의 토큰이 새 세션을 덮어쓰지 않는다(테스트로 고정).
- `./.claude/scripts/xcbuild.sh test`, `build`, `build -configuration Release`, `swiftformat --lint .`,
  `swiftlint lint --quiet` 가 통과한다. 각 단계 커밋마다 통과한다.

## 범위 밖

- 로그인 화면(피처 모듈), 세션 만료 시 화면 전환. 이번에는 `AuthRepository` 까지만 만든다.
- Sign in with Apple, OAuth(`ASWebAuthenticationSession`). 명세(`openapi.yaml`)에 근거가 없다.
- 서버 로그아웃 호출. 명세에 logout operation 이 없으므로 로그아웃은 로컬 토큰 삭제뿐이다.
- 앱 익스텐션과 토큰 공유(`keychain-access-groups`). 지금 익스텐션(NotificationService)은 토큰을 쓰지 않는다.
- 새 외부 의존성. 시스템 프레임워크(Security, os)와 기존 패키지만 쓴다.

## 전제

### 버전과 환경
- iOS 17.0, Swift 6.0 언어 모드, Tuist 4.208.0(`mise.toml`). `enforceExplicitDependencies` 가 켜져 있어 import 하는
  모듈은 해당 타깃의 `*Dependencies` 에 모두 적어야 한다.
- 새로 쓰는 플랫폼 API 는 없다. 기존 코드가 이미 쓰는 것뿐이다: Security `SecItemCopyMatching`/`SecItemAdd`/
  `SecItemUpdate`/`SecItemDelete`(iOS 2.0), `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`(iOS 4.0),
  OpenAPIRuntime `ClientMiddleware`. 가용성 분기는 필요 없다.

### 현재 코드 (2026-09-28, main `96b8bf4`)
모두 `Modules/Core/Networking/` 아래다.

| 파일 | 내용 | 접근 |
| --- | --- | --- |
| `Sources/Auth/AuthTokens.swift:10` | `struct AuthTokens: Sendable, Equatable, Codable` (access, refresh) | public |
| `Sources/Auth/AuthenticationError.swift:7` | `.sessionExpired`(토큰 삭제됨), `.refreshFailed`(토큰 유지) | public |
| `Sources/Auth/TokenStore.swift:9` | `protocol TokenStore: Sendable { load/save/clear async throws }` | public |
| `Sources/Auth/KeychainTokenStore.swift:14` | generic password 1개에 JSON 저장. `init(service:)` | public |
| `Sources/Auth/KeychainError.swift:9` | `.unexpectedStatus(OSStatus)`, `.invalidData` | public |
| `Sources/Auth/TokenRefresher.swift:12` | `actor TokenRefresher`: 갱신 단일화(`inFlight`), 저장 실패 시 `unsaved` 보관, 만료 시 `store.clear()` 후 `onSessionExpired` | internal |
| `Sources/Middleware/AuthMiddleware.swift:13` | `ClientMiddleware`. 공개 operation 은 통과, 토큰 부착, 401 이면 `refreshedAccessToken(rejected:)` 후 1회 재전송 | internal |
| `Sources/Middleware/PublicOperation.swift:10` | `["login", "refreshToken"]`. `openapi.yaml` 의 operationId 와 수동 동기화 | internal |
| `Sources/APIClientFactory.swift:26-59` | `make(baseURL:session:tokenStore:logSubsystem:activityObserver:onSessionExpired:)`. refresh 전용 클라이언트(Auth 미들웨어 없음)로 재귀 방지, `TokenRefresher` 와 미들웨어 조립 | public |
| `Sources/APIClientFactory.swift:65-79` | `refreshTokens(using:refreshToken:)`: 200→토큰, 400/401→`sessionExpired`, undocumented→`refreshFailed` | internal |
| `Sources/Diagnostics/NetworkFailure.swift:76` | `error is AuthenticationError` 면 보고하지 않음 | — |
| `Testing/Sources/InMemoryTokenStore.swift:11` | `actor InMemoryTokenStore: TokenStore`, `saveCount`/`clearCount` 기록 | public |

- **핵심 제약** `TokenRefresher.swift:20-25`: `unsaved` 가 있는 동안 저장소를 읽지 않는다. 로그인·로그아웃이 저장소에
  직접 쓰면 새 토큰이 `unsaved` 에 가려진다. 그러므로 세션을 바꾸는 모든 경로는 갱신과 **같은 actor** 를 거친다.
- actor 재진입: `inFlight` 확인과 저장은 `await` 없이 이어서 한다(`TokenRefresher.swift:8-11`, 53-74행). 옮길 때 유지한다.
- 테스트: `Tests/TokenRefresherTests.swift`, `Tests/AuthMiddlewareTests.swift`, `Tests/APIClientFactoryTests.swift` 가
  `@testable import Networking` + `NetworkingTesting` 의 `InMemoryTokenStore` 를 쓴다(두 파일 합쳐 `@Test` 19개).
  `Tests/NetworkFailureTests.swift:46,80,170` 이 `AuthenticationError` 를 쓴다.
- 사용처: `App/Sources/DI/AppContainer.swift:11`(import Networking), `57-70`(`APIClientFactory.make`,
  `KeychainTokenStore(service: bundleIdentifier)`, `onSessionExpired` 는 로그만). 다른 모듈은 Auth 타입을 쓰지 않는다.
- 명세 `Modules/Core/Networking/OpenAPI/openapi.yaml`: 전역 `security: bearerAuth`. `/auth/login`(`login`,
  `security: []`, 본문 `LoginRequest { email, password }`, 200 `TokenPair`, 401 `ErrorResponse`),
  `/auth/refresh`(`refreshToken`, 200/400/401). logout 은 없다. 생성 `Operations.Login.Output` 은
  `.ok`, `.unauthorized`, `.undocumented` 다.
- Data 의 보고 규칙: `Modules/Core/Data/Sources/RemoteItemRepository.swift:14,58` — 생성 클라이언트 호출의 `catch` 에서
  `NetworkFailure.describe(_:)` 로 판정해 보고한다. 새 Repository 도 따른다.
- Data 테스트의 `StubAPI` 는 `Modules/Core/Data/Tests/RemoteItemRepositoryTests.swift:125-` 에 `private` 으로 있다.

### 모듈 규칙 (`Tuist/ProjectDescriptionHelpers/Module.swift`)
- 이름 있는 case 로 올리는 기준(187-193행 주석): 규칙을 여러 쌍에 걸쳐 적어야 할 때. Auth 는 Networking 과 Data 가
  의존하므로 `.auth` 로 둔다. `name`(196-221행), `path`(223-230행) switch 에 case 를 더한다.
- `mayDepend(on:)`(305-324행)에 `(.networking, .auth)`, `(.data, .auth)` 를 더한다. 지원 타깃은 허용 모듈의 `*Testing`
  에도 의존할 수 있으므로 `.testing(.auth)` 는 추가 규칙이 필요 없다. App 은 규칙 없이 의존한다.
- 규칙이 빠지면 generate 가 문구 없이 멈춘다. 문구는 오류에 찍힌 `xcrun swift ... --tuist-dump` 명령으로 본다.
- `Scripts/new-module.sh core Auth --testing` 은 `Module.all` 에 `.core("Auth")` 로 등록한다. `.auth` 로 바꾼다.

### 알려진 함정 (플랫폼 조사)
- `SecItem*` 은 호출 스레드를 막는다. `KeychainTokenStore` 의 async 메서드는 nonisolated 라 호출한 actor 밖에서 돈다.
  메인 액터에서 동기로 부르는 경로를 만들지 않는다.
- 동시 401 의 중복 갱신은 기존 `inFlight` 로 막혀 있다. 여기에 로그인·로그아웃이 끼어드는 경우가 새로 생긴다(결정 사항 참고).

## 결정 사항

| 결정 | 선택 | 이유 |
| --- | --- | --- |
| 의존 방향 | Networking → Auth. Auth 는 Foundation·Security·os 만 import | 명세·생성물과 엮인 코드(미들웨어, operationId, refresh 호출)를 Networking 한 곳에 둔다. 명세가 바뀌어도 Auth 는 영향 없음 |
| Auth 에 두는 것 | `AuthTokens`, `AuthenticationError`, `TokenStore`, `KeychainTokenStore`, `KeychainError`, `AuthSession`(←`TokenRefresher`) | 토큰 수명주기 전체. `AuthMiddleware`, `PublicOperation`, `refreshTokens` 는 Networking 에 남긴다 |
| 갱신 actor | `TokenRefresher` 를 public `actor AuthSession` 으로 이름을 바꾸고 로그인·로그아웃·상태를 더한다 | `unsaved`·`inFlight` 불변식 때문에 세션을 바꾸는 경로가 같은 actor 에 있어야 한다 |
| 만료 알림 | `onSessionExpired` 콜백을 없애고 `AuthSession.states()` 스트림의 `.expired` 로 알린다. 만료 로그는 `AuthSession` 이 남긴다 | 콜백과 스트림 두 경로를 두지 않는다. 피처는 Domain 스트림으로 받는다 |
| 상태 스트림 | `func states() -> AsyncStream<AuthSession.State>`, 구독마다 continuation 을 따로 두고 첫 값으로 현재 상태를 보낸다 | `AsyncStream` 은 소비자 하나라 여러 구독자에 나눠 줄 수 없다. 늦게 구독해도 현재 상태를 안다 |
| 세대 구분 | `signIn`/`signOut`/만료 때 세대 번호를 올리고, 갱신 Task 는 시작 세대와 같을 때만 저장·`unsaved` 반영 | 로그아웃 뒤 끝난 이전 세션의 갱신이 토큰을 되살리거나, 새 로그인 토큰을 덮어쓰는 것을 막는다 |
| 로그인 저장 실패 | 에러를 던진다(상태는 바꾸지 않음) | 갱신과 달리 이전 토큰을 무효로 만든 것이 아니다. 사용자가 다시 시도하면 된다 |
| 로그아웃 | 로컬 삭제만. 삭제 실패해도 `unsaved` 를 비우고 `.signedOut` 을 보낸 뒤 에러를 던진다 | 명세에 logout 이 없다. 남은 토큰은 다음 로그인 때 덮인다 |
| APIClientFactory 조립 | `makeTokenRefresh(baseURL:session:logSubsystem:activityObserver:) -> AuthSession.Refresh` 와 `make(baseURL:session:authSession:logSubsystem:activityObserver:)` 로 나눈다 | App 이 `AuthSession` 을 먼저 만들고 두 곳(미들웨어, Repository)에 같은 인스턴스를 넘긴다. refresh 클라이언트의 재귀 방지는 유지 |
| 피처 노출 | Domain `AuthRepository` + `AuthError` + `SessionStatus`, Data `RemoteAuthRepository` | 기존 `ItemRepository` 패턴. 피처 의존 규칙(Feature → Domain)을 바꾸지 않는다 |
| 이름 | Auth: `AuthSession.State { signedIn, signedOut, expired }`. Domain: `SessionStatus`(같은 세 case) | Data 가 두 모듈을 함께 import 하므로 이름이 겹치지 않게 한다 |
| 로그인 에러 | Domain `AuthError { invalidCredentials, unavailable }`. 401 → `invalidCredentials`, 그 밖(undocumented, 전송 실패, 저장 실패) → `unavailable` | 화면이 구분해야 하는 것은 "자격 증명이 틀림" 과 "다시 시도" 둘이다 |
| 테스트 지원 | `InMemoryTokenStore` 를 `AuthTesting` 으로 옮긴다. `DomainTesting` 에 `StubAuthRepository` | Networking·Data 테스트가 함께 쓴다 |

## 변경 계획

각 단계는 독립적으로 generate·빌드·테스트가 통과하고 커밋 하나다.

### 1. Auth 모듈 생성과 타입 이동 (동작 변화 없음)
- 파일: `Scripts/new-module.sh core Auth --testing` 로 `Modules/Core/Auth/` 생성 후 샘플 파일 삭제.
- 변경:
  - `Module.swift`: `.core("Auth")` 등록을 `case auth` 로 바꾸고 `name`·`path` switch, 상단 의존 그림, `Module.all`
    (`.auth`)을 고친다. `mayDepend` 에 `(.networking, .auth)` 추가.
  - `git mv` 로 `AuthTokens`, `AuthenticationError`, `TokenStore`, `KeychainTokenStore`, `KeychainError` 를
    `Modules/Core/Auth/Sources/` 로, `InMemoryTokenStore` 를 `Modules/Core/Auth/Testing/Sources/` 로 옮긴다.
    헤더 주석의 모듈 이름을 고친다. `InMemoryTokenStore` 는 `import Auth`.
  - `Modules/Core/Auth/Project.swift`: `Project.core(name: "Auth", hasTestingSupport: true)`. 문서 주석에 import 제한
    (Foundation, Security, os)을 적는다.
  - `Modules/Core/Networking/Project.swift`: `dependencies` 에 `.module(.auth)`, `testDependencies` 에 `.module(.auth)`,
    `.testing(.auth)`. 주석의 `InMemoryTokenStore` 설명 갱신.
  - Networking 소스·테스트에 `import Auth`, 테스트에 `import AuthTesting` 을 더한다(`TokenRefresher.swift`,
    `AuthMiddleware.swift`, `APIClientFactory.swift`, `NetworkFailure.swift`, 네 테스트 파일).
  - `App/Project.swift` 에 `.module(.auth)`, `AppContainer.swift` 에 `import Auth`.
  - `NetworkingTesting` 에 `RecordingNetworkActivityObserver` 만 남는다. 매니페스트는 그대로 둔다.
- 검증: `mise exec -- tuist generate`, `xcbuild.sh test` 통과. `@Test` 개수가 이전과 같다(결과 번들의 총 개수 비교).

### 2. `TokenRefresher` → `AuthSession` 이동과 조립 분리 (동작 변화 없음)
- 파일: `Modules/Core/Networking/Sources/Auth/TokenRefresher.swift` → `Modules/Core/Auth/Sources/AuthSession.swift`,
  `Tests/TokenRefresherTests.swift` → `Modules/Core/Auth/Tests/AuthSessionTests.swift`,
  `AuthMiddleware.swift`, `APIClientFactory.swift`, `AppContainer.swift`, `AuthMiddlewareTests.swift`, `APIClientFactoryTests.swift`.
- 변경:
  - 타입을 `public actor AuthSession` 으로, `Refresh` typealias·`init`·`currentAccessToken()`·
    `refreshedAccessToken(rejected:)` 를 public 으로. 이 단계에서는 `onSessionExpired` 를 유지한다.
  - `AuthMiddleware` 가 `AuthSession` 을 받는다.
  - `APIClientFactory`: `makeTokenRefresh(...)` 가 refresh 전용 클라이언트를 만들어 `refreshTokens` 를 부르는 클로저를
    돌려준다. `make(...)` 는 `authSession: AuthSession` 을 받는다. 미들웨어 순서(RequestID → Logging → Retry → Auth)와
    refresh 클라이언트에 Auth 미들웨어가 없는 것은 유지한다. 문서 주석 갱신.
  - `AppContainer`: `KeychainTokenStore` → `AuthSession(store:refresh:onSessionExpired:logger:)` → `make(authSession:)` 순서.
  - 테스트는 `@testable import Networking` 대신 `import Auth` 로 `AuthSession` 을 쓴다. 테스트 내용은 바꾸지 않는다.
- 검증: 테스트 통과, `@Test` 개수 동일. `Modules/Core/Auth` 에서 `grep -rn "OpenAPI\|HTTPTypes"` 가 비어 있다.

### 3. `AuthSession` 에 로그인·로그아웃·상태 추가
- 파일: `Modules/Core/Auth/Sources/AuthSession.swift`, `AuthSession+State.swift`(중첩 `State` 가 길면 분리),
  `Modules/Core/Auth/Tests/AuthSessionTests.swift`, `AppContainer.swift`, `Modules/Core/Networking/Tests/AuthMiddlewareTests.swift`.
- 변경:
  - `public enum State: Equatable, Sendable { case signedIn, signedOut, expired }`.
  - `public func signIn(with tokens: AuthTokens) async throws`: 세대 +1, `inFlight = nil`, `store.save` 성공 시
    `unsaved = nil` 후 `.signedIn` 방송. 실패하면 던지고 상태를 바꾸지 않는다.
  - `public func signOut() async throws`: 세대 +1, `inFlight = nil`, `unsaved = nil`, `store.clear()`, `.signedOut` 방송.
    삭제 실패는 방송 뒤 던진다.
  - 만료(`expireSession`): 세대 +1 후 기존 처리, `.expired` 방송, `logger.notice` 로 만료 로그. `onSessionExpired` 제거.
  - 갱신 Task 는 시작 세대를 캡처하고, 끝났을 때 세대가 바뀌었으면 저장·`unsaved` 를 건너뛰고
    `AuthenticationError.sessionExpired` 를 던진다(대기 중인 요청은 새 토큰으로 다시 요청하지 않고 실패한다).
  - `public func states() -> AsyncStream<State>`: 구독 id 별 continuation 을 actor 에 저장, 첫 값은 현재 상태
    (`loadTokens()` 가 토큰을 주면 `.signedIn`, 아니면 `.signedOut`. 읽기 실패는 `.signedOut` 으로 보고 로그를 남긴다).
    `onTermination` 에서 `Task { await self.removeContinuation(id) }` 로 지운다.
  - `AppContainer` 의 `onSessionExpired` 클로저와 `LogCategory.session` 로거를 `AuthSession(logger:)` 로 옮긴다.
- 검증: 아래 테스트 전략의 3단계 테스트 통과.

### 4. Domain·Data 의 `AuthRepository`
- 파일: `Modules/Core/Domain/Sources/AuthRepository.swift`, `AuthError.swift`, `SessionStatus.swift`,
  `Modules/Core/Domain/Testing/Sources/StubAuthRepository.swift`,
  `Modules/Core/Data/Sources/RemoteAuthRepository.swift`, `Modules/Core/Data/Project.swift`,
  `Modules/Core/Data/Tests/RemoteAuthRepositoryTests.swift`, `Modules/Core/Data/Tests/StubAPI.swift`(추출),
  `Tuist/ProjectDescriptionHelpers/Module.swift`.
- 변경:
  - Domain(Foundation 만):
    `protocol AuthRepository: Sendable { func signIn(email: String, password: String) async throws(AuthError);
    func signOut() async throws(AuthError); func sessionStatuses() async -> AsyncStream<SessionStatus> }`.
  - `RemoteAuthRepository(client: any APIProtocol, session: AuthSession, reporter: any DiagnosticReporting)`:
    `login` 호출 → `.ok` 면 `AuthTokens` 로 바꿔 `session.signIn(with:)`, `.unauthorized` → `invalidCredentials`,
    `.undocumented`·전송 실패 → `unavailable`(보고는 `RemoteItemRepository` 규칙), 저장 실패 → `unavailable`.
    `signOut` 실패 → `unavailable`. `sessionStatuses()` 는 `AuthSession.states()` 를 `SessionStatus` 로 바꾼 스트림
    (전달 Task 를 `onTermination` 에서 취소).
  - `Module.swift`: `(.data, .auth)` 추가. `Data/Project.swift`: `dependencies`·`testDependencies` 에 `.module(.auth)`,
    테스트에 `.testing(.auth)`.
  - `RemoteItemRepositoryTests.swift` 의 `private struct StubAPI` 를 같은 테스트 타깃의 `StubAPI.swift`(internal)로 옮기고
    `login` 결과를 설정할 수 있게 한다. 기존 테스트 동작은 그대로.
- 검증: generate·테스트 통과.

### 5. App 조립과 문서
- 파일: `App/Sources/DI/AppContainer.swift`, `README.md`, `Modules/Core/Networking/README.md`,
  `Modules/Core/Auth/README.md`(신규), `Tuist/ProjectDescriptionHelpers/Module.swift` 상단 그림.
- 변경:
  - `AppContainer` 에 `let authRepository: any AuthRepository` 를 두고 `RemoteAuthRepository` 로 채운다.
    `AuthSession` 인스턴스 하나를 `APIClientFactory.make` 와 `RemoteAuthRepository` 가 함께 쓴다. 문서 주석의 구현 타입 목록 갱신.
  - README 구조·의존 그림에 Auth 추가. Networking README 의 토큰 설명을 Auth README 로 옮기고 링크.
    Auth README: 공개 API, 세대 규칙, `unsaved`, 상태 스트림, 로그인 화면을 붙이는 방법(피처는 `AuthRepository` 만).
  - `PublicOperation` 주석에 "로그인 operation 을 추가하면 여기와 `RemoteAuthRepository` 를 함께" 를 더한다.
- 검증: 전체 테스트, Debug·Release 빌드, 포맷·린트 통과.

## 테스트 전략

**옮기는 테스트(내용 유지)**
- `TokenRefresherTests` → `AuthSessionTests`: 단일 갱신, `rejected` 비교, `unsaved`, 만료 시 삭제·1회 알림.
  만료 알림 검증은 3단계에서 `onSessionExpired` 호출 횟수 → `states()` 의 `.expired` 수신으로 바꾼다.
- `AuthMiddlewareTests`, `APIClientFactoryTests`, `NetworkFailureTests`: import 만 바뀐다.

**추가(`AuthSessionTests`)**
- `signIn_saves_tokensAndEmitsSignedIn`: 저장되고 `.signedIn` 이 온다.
- `signIn_storeFails_throwsAndKeepsState`: 저장 실패 시 던지고 상태 스트림에 새 값이 없다.
- `signIn_afterUnsaved_newTokensWin`: 갱신 저장 실패로 `unsaved` 가 있을 때 로그인하면 `currentAccessToken()` 이 새 토큰이다.
- `signOut_clearsAndEmitsSignedOut`: 삭제·`unsaved` 비움·`.signedOut`.
- `signOut_storeFails_emitsSignedOutAndThrows`.
- `refresh_finishesAfterSignOut_doesNotRestoreTokens`: refresh 클로저를 continuation 으로 붙잡아 둔 채 `signOut` →
  refresh 완료 → 저장소가 비어 있고 대기하던 호출은 `sessionExpired`.
- `refresh_finishesAfterSignIn_keepsNewTokens`: 같은 방식으로 `signIn` 끼워 넣기.
- `states_firstValue_reflectsStoredTokens`: 토큰 유무에 따라 첫 값이 `.signedIn`/`.signedOut`.
- `states_multipleSubscribers_eachReceive`: 두 구독자가 모두 `.expired` 를 받는다.
- 동기화는 `sleep` 없이 continuation·`AsyncStream` 반복으로 한다(`.claude/rules/tests.md`).

**추가(`RemoteAuthRepositoryTests`, `StubAPI` + `InMemoryTokenStore` + `SpyDiagnosticReporter`)**
- 200 → 토큰 저장, `sessionStatuses` 가 `.signedIn`.
- 401 → `invalidCredentials`, 저장 없음, 보고 없음.
- undocumented → `unavailable`, 보고 규칙은 `RemoteItemRepositoryTests` 와 같은 기준.
- 클라이언트 throw → `unavailable`.
- `signOut` → 저장소 비움, `.signedOut`.

**App**: 기존 `AppContainer*Tests` 가 통과하는지 확인. 새 App 테스트는 두지 않는다(조립만 한다).

## 위험 요소

| 위험 | 가능성 | 대응 |
| --- | --- | --- |
| 옮기면서 `inFlight` 확인·저장 사이에 `await` 가 끼어 재진입 불변식이 깨짐 | 중 | 2단계는 코드 변경 없이 이동만. 3단계의 세대 확인도 `await` 없이 이어서 한다. 기존 동시성 테스트 유지 |
| `mayDepend` 규칙 누락으로 generate 가 문구 없이 멈춤 | 중 | 단계마다 generate. 멈추면 `--tuist-dump` 명령으로 문구 확인 |
| `onTermination` 이 actor 밖에서 불려 continuation 정리가 늦음 | 낮 | 정리 전 방송은 종료된 continuation 에 yield 해도 무해하다. 누수만 없으면 된다(테스트: 구독 취소 후 내부 개수 — 구현 중 확인, 필요하면 internal 조회 추가) |
| 세대 불일치로 대기 요청이 `sessionExpired` 를 받아 화면에 로그인 오류가 잠깐 뜸 | 낮 | 로그아웃·재로그인 직후의 진행 중 요청에 한정. 피처는 `SessionStatus` 로 판단하도록 Auth README 에 적는다 |
| Swift 6.2 `NonisolatedNonsendingByDefault` 를 나중에 켜면 `KeychainTokenStore` 가 호출자 격리에서 돈다 | 낮 | 호출자가 `AuthSession`(메인 아님)이라 UI 는 막지 않는다. Auth README 에 메인 액터에서 직접 부르지 말라고 적는다 |
| 테스트 개수 누락(옮기다 파일이 스킴에서 빠짐) | 낮 | 1·2단계 검증에서 결과 번들의 총 `@Test` 개수를 이전과 비교 |

## 롤백

- 단계별 커밋이므로 문제가 생긴 단계부터 `git revert` 한다. 1·2단계는 동작 변화가 없어 되돌려도 저장 형식
  (Keychain 서비스·계정 이름, JSON)은 같다. 3단계 이후도 저장 형식은 바꾸지 않으므로 이미 설치된 앱의 토큰은 유지된다.
- 되돌린 뒤 `mise exec -- tuist generate` 를 다시 돌린다(`Modules/Core/Auth` 가 남아 있으면 `Module.all` 과 어긋나 멈추므로
  폴더도 함께 지워졌는지 확인).
