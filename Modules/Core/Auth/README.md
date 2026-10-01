# Auth

로그인 세션의 토큰 모델·저장소·갱신·상태를 맡는다. Foundation, Security, os 외에는 import 하지 않는다.
API 명세·생성 클라이언트와 엮인 코드(인증 미들웨어, 공개 operationId, refresh 호출)는 Networking 에 있다.
명세가 바뀌어도 이 모듈은 영향받지 않는다.

의존 방향: Networking → Auth, Data → Auth. App 이 조립한다. Feature 는 이 모듈을 모르고 Domain 의 `AuthRepository` 만 쓴다.

## 구성

| 위치 | 내용 |
|---|---|
| `Sources/AuthSession.swift` | 토큰 읽기, 401 갱신 단일화, 로그인·로그아웃, 상태 스트림 (`actor`) |
| `Sources/AuthSessionState.swift` | `AuthSessionState { signedIn, signedOut, expired }` (`AuthSession.State` 로도 부른다) |
| `Sources/AccessTokenProviding.swift` | 미들웨어가 의존하는 프로토콜(토큰 읽기·401 갱신) |
| `Sources/SessionToken.swift` | 요청에 붙인 access token 과 그 토큰을 읽은 세션의 세대. 401 갱신 때 그대로 돌려준다 |
| `Sources/SessionManaging.swift` | Repository 가 의존하는 프로토콜(로그인·로그아웃·상태) |
| `Sources/AuthTokens.swift` | access·refresh token 한 쌍. 생성 타입 `TokenPair` 와 분리한 저장 모델 |
| `Sources/AuthenticationError.swift` | 갱신 실패. `sessionExpired`(토큰 삭제됨), `refreshFailed`(토큰 유지) |
| `Sources/TokenStore.swift` | 저장소 프로토콜 |
| `Sources/KeychainTokenStore.swift`, `KeychainError.swift` | Keychain generic password 1개에 JSON 으로 저장(`AfterFirstUnlockThisDeviceOnly`) |
| `Testing/Sources/` | `InMemoryTokenStore` (`saveCount`, `clearCount` 기록), `FailingTokenStore` (저장·삭제 실패) |
| `Demo/Sources/` | AuthDemo. 실제 Keychain 저장과 로그인·로그아웃·만료 상태 전이를 화면으로 확인한다(`Auth` 스킴으로 실행) |

## 공개 API (`AuthSession`)

| 메서드 | 쓰는 곳 | 동작 |
|---|---|---|
| `init(store:refresh:logger:)` | App | `refresh` 는 Networking 의 `APIClientFactory.makeTokenRefresh(...)` 로 만든다 |
| `currentAccessToken()` | Networking 미들웨어 | 요청에 붙일 토큰(`SessionToken.value`, 로그인 전이면 `nil`)과 읽은 시점의 세대 |
| `refreshedAccessToken(rejected:)` | Networking 미들웨어 | 401 뒤 새 토큰. `rejected` 에는 `currentAccessToken()` 이 준 값을 그대로 넘긴다. 동시 호출은 갱신 한 번으로 모은다 |
| `signIn(with:)` | Data `RemoteAuthRepository` | 저장 성공 시 `.signedIn`. 저장 실패는 로그를 남기고 던지며 상태를 바꾸지 않는다. 저장 중 로그아웃이 먼저 끝나면 `CancellationError` |
| `signOut()` | Data `RemoteAuthRepository` | 메모리·저장소를 비우고 `.signedOut`. 삭제 실패는 알리고 로그를 남긴 뒤 던진다 |
| `states()` | Data `RemoteAuthRepository` | 구독마다 따로 만드는 상태 스트림. 첫 값은 현재 상태 |

Networking 은 `AccessTokenProviding`, Data 는 `SessionManaging` 프로토콜로 받는다. `AuthSession` 인스턴스는 앱에 하나만 두고
두 곳에 같은 인스턴스를 넘긴다. 그래야 아래 규칙이 성립한다.

## 동작 규칙

### 세션을 바꾸는 경로는 모두 `AuthSession` 을 거친다

갱신 뒤 저장에 실패한 새 토큰은 메모리(`unsaved`)에 들고, 값이 있는 동안에는 저장소보다 먼저 읽는다.
서버가 refresh token 을 교체했다면 이전 토큰은 이미 무효이기 때문이다. 그래서 `TokenStore` 에 직접 쓰면
새 토큰이 `unsaved` 에 가려진다. 로그인·로그아웃·만료는 모두 `unsaved` 를 비운다.

### 세대

로그인·로그아웃·만료 때마다 세대 번호를 올리고 진행 중인 갱신을 떼어 낸다. 갱신은 갱신할 토큰을 **읽기 전에** 잡은 세대가
끝날 때까지 그대로일 때만 결과를 저장한다(읽는 동안 세션이 바뀌면 갱신을 시작하지 않는다). 그렇지 않으면 저장하지 않고 기다리던 호출에 `AuthenticationError.sessionExpired` 를 던진다.

- 로그아웃 뒤에 끝난 이전 세션의 갱신이 토큰을 되살리지 않는다.
- 로그인 뒤에 끝난 이전 세션의 갱신이 새 토큰을 덮어쓰지 않는다.
- 이전 세션의 갱신이 거절돼도 새 세션을 만료시키지 않는다.
- 요청이 토큰을 읽은 뒤 세션이 바뀌었으면(`SessionToken` 의 세대가 다르면) 그 요청의 401 로는 갱신하지 않고 `sessionExpired` 를 던진다.
  이전 세션의 요청이 새 세션 토큰으로 다시 나가지 않는다.

그 결과 로그아웃·재로그인 직후 진행 중이던 요청은 새 토큰으로 다시 보내지 않고 실패한다.
화면은 이 에러가 아니라 `SessionStatus` 로 로그인 여부를 판단한다.

로그인은 저장 **전에** 세대를 올린다. 그래서 로그인 저장에 실패하면 진행 중이던 갱신 결과도 버려진다.
저장 뒤에 올리면 앞선 갱신의 저장이 새 로그인 토큰을 덮어쓸 수 있어서, 드문 이 손실을 택했다.

### 로그아웃·만료 뒤의 읽기

로그아웃·만료가 시작되면 삭제 결과와 관계없이 이 프로세스에서는 저장소를 읽지 않는다(로그인에 성공하면 해제).
삭제가 끝나기 전에 들어온 읽기나 삭제가 실패한 뒤의 읽기가 이전 토큰을 돌려주지 않게 하기 위해서다.
앱을 다시 시작하면 남은 토큰을 읽는다. 만료였다면 서버가 다시 거절해 삭제가 재시도된다.
로그아웃이었다면 다시 로그인된 상태로 보인다. Keychain 삭제 실패는 드물어서 받아들인 한계다.

### 저장소 접근 순서

저장소 읽기·저장·삭제는 `AuthSession` 이 요청한 순서대로 하나씩 실행한다. 갱신 결과를 저장하는 중에 로그아웃하면
삭제가 그 저장 뒤에 실행되어 토큰이 남지 않는다. 로그인 저장도 앞선 갱신 저장 뒤에 실행된다.

### 상태 스트림

- `states()` 는 구독마다 continuation 을 따로 둔다(`AsyncStream` 은 소비자가 하나라 나눠 줄 수 없다).
- 첫 값은 현재 상태다. 아직 전환이 없었으면 저장소의 토큰 유무로 `.signedIn`/`.signedOut` 을 정하고, 읽기에 실패하면 `.signedOut` 으로 보고 로그를 남긴다.
- 만료(`.expired`)는 refresh 가 400/401 로 거절될 때 한 번만 온다. 만료 로그도 `AuthSession` 이 남긴다.
- 구독을 끝내려면 순회하는 Task 를 취소한다. 내부 continuation 은 종료 콜백에서 지운다.

### 테스트 동기화 지점

`rejecting(_:)`(지금 세대의 `SessionToken` 만들기), `isRefreshInFlight`, `waitUntilGeneration(atLeast:)`, `waitUntilNoSubscribers()` 는 internal 이며 `@testable import` 하는 테스트만 쓴다.
sleep 없이 전환 시점을 맞추기 위한 것이다. 앱 코드에서 쓰지 않는다.

## 로그인 화면을 붙일 때

피처는 Auth 도 Data 도 모른다. Domain 의 `AuthRepository` 만 받는다.

1. 피처의 뷰모델이 `AuthRepository` 를 생성자로 받는다. App 은 `AppContainer.authRepository` 를 넘긴다.
2. 로그인: `try await repository.signIn(email:password:)`. `AuthError.invalidCredentials` 는 입력 오류, `.unavailable` 은 "다시 시도" 로 보여 준다.
3. 로그아웃: `try await repository.signOut()`. 실패해도 상태는 `.signedOut` 이 된다.
4. 세션 만료 화면 전환은 `for await status in await repository.sessionStatuses()` 로 받는다. `.expired` 면 로그인 화면으로 보낸다.
5. 테스트·데모는 DomainTesting 의 `StubAuthRepository` 를 쓴다.

## 주의

- `KeychainTokenStore` 의 메서드는 `SecItem*` 을 부르며 호출 스레드를 막는다. 메인 액터에서 직접 부르지 않는다.
  앱에서는 `AuthSession`(메인 액터가 아님)만 부른다. Swift 6.2 의 `NonisolatedNonsendingByDefault` 를 켜면
  호출자 격리에서 돌게 되므로 이 전제가 더 중요해진다.
- 명세에 logout operation 이 없어서 로그아웃은 로컬 삭제뿐이다. 서버 로그아웃이 생기면 `RemoteAuthRepository.signOut()` 에서 부른다.
- 명세에 로그인 operation 을 추가하면 Networking 의 `PublicOperation.ids` 와 Data 의 `RemoteAuthRepository` 를 함께 고친다.
