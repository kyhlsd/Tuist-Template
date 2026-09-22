# Networking

OpenAPI 명세(`OpenAPI/openapi.yaml`)에서 생성한 API 클라이언트와, 그 위에서 인증·재시도·로그를 처리하는 미들웨어를 제공한다.

> `openapi.yaml` 은 임시 명세다. 서버 명세가 확정되면 교체한다.

## 특징

- **명세 주도**: 명세를 고치고 스크립트를 돌리면 `APIProtocol`, 요청·응답 타입이 다시 만들어진다. 명세와 코드가 어긋나면 컴파일 단계에서 드러난다.
- **자동 인증**: 공개 operation 을 뺀 모든 요청에 `Authorization: Bearer <access token>` 이 붙는다.
- **토큰 갱신**: 401 을 받으면 refresh token 으로 한 번 갱신하고 원 요청을 한 번 다시 보낸다. 동시에 401 이 여러 개 와도 refresh 호출은 한 번이다.
- **세션 만료 알림**: refresh 가 400/401 로 거절되면 토큰을 지우고 `onSessionExpired` 를 한 번 부른다. 네트워크 문제로 refresh 가 실패하면 토큰은 유지한다.
- **재시도**: 멱등 요청(GET/HEAD/PUT/DELETE)은 연결 끊김·호스트 연결 실패·502/503 에서 최대 2회(0.5초, 1초 뒤) 다시 보낸다. 타임아웃과 504, 취소는 다시 보내지 않는다.
- **안전한 로그**: `os.Logger` 로 method, path(쿼리 제외), status, 소요 시간만 남긴다. 헤더·토큰·바디는 남기지 않는다.
- **Keychain 저장**: 토큰은 `KeychainTokenStore` 가 기기 전용(`AfterFirstUnlockThisDeviceOnly`)으로 저장한다.

## 구성

| 위치 | 내용 |
|---|---|
| `OpenAPI/` | 명세와 생성기 설정 |
| `Sources/Generated/` | 생성물(`APIProtocol`, `Client`, `Components`, `Operations`). 손으로 고치지 않는다 |
| `Sources/APIClientFactory.swift` | 클라이언트 조립. App 만 호출한다 |
| `Sources/NetworkDefaults.swift` | 타임아웃, 재시도 횟수 등 기본값 |
| `Sources/Auth/` | `AuthTokens`, `TokenStore`, `KeychainTokenStore`, `TokenRefresher` |
| `Sources/Middleware/` | `LoggingMiddleware`, `RetryMiddleware`, `AuthMiddleware`, `PublicOperation` |
| `Testing/Sources/` | `InMemoryTokenStore` (테스트용) |

의존 방향: App → Data → Networking. Data 는 `APIProtocol` 에만 의존하고, Feature 는 이 모듈을 모른다.

## 사용법

### 조립 (App)

세션은 앱 수명 동안 하나만 만들어 둔다.

```swift
let session = APIClientFactory.makeSession()
let client = APIClientFactory.make(
    baseURL: configuration.apiBaseURL,
    session: session,
    tokenStore: KeychainTokenStore(service: bundleIdentifier),
    logSubsystem: bundleIdentifier,
    onSessionExpired: { /* 로그인 화면으로 보내기 등 */ }
)
let repository = RemoteItemRepository(client: client)
```

### 호출 (Data)

생성된 메서드는 응답 상태별 case 를 가진 `Output` 을 돌려준다. 생성 타입은 Data 안에서 도메인 모델로 바꾸고 위로 올리지 않는다.

```swift
public func fetchItems() async throws(ItemError) -> [Item] {
    let output: Operations.ListItems.Output
    do {
        output = try await client.listItems()
    } catch {
        throw .unavailable          // 전송 실패, 디코딩 실패, 세션 만료
    }
    switch output {
    case let .ok(ok):
        do {
            return try ok.body.json.map { $0.toDomain() }
        } catch {
            throw .invalidData      // 본문이 JSON 이 아닐 때(지금 명세에서는 일어나지 않음)
        }
    case .unauthorized, .undocumented:
        throw .unavailable
    }
}
```

`client.listItems()` 가 던지는 에러는 `ClientError` 이고, 원래 원인은 `underlyingError` 에 들어 있다.
예를 들어 `URLError` 나 `AuthenticationError.sessionExpired` 가 들어 있을 수 있다.

### API 추가·수정

1. `OpenAPI/openapi.yaml` 에 operation 과 schema 를 적는다. `operationId` 가 생성되는 메서드 이름이 된다.
2. 저장소 루트에서 생성한다.

   ```bash
   Scripts/openapi-generate.sh
   ```

3. 생성 파일이 새로 생겼으면 프로젝트를 다시 만든다.

   ```bash
   mise exec -- tuist generate --no-open
   ```

4. 토큰 없이 호출하는 operation(명세에 `security: []`)이면 `PublicOperation.ids` 에 `operationId` 를 넣는다.
   빠지면 그 operation 의 401(예: 로그인 실패)이 토큰 갱신을 일으킨다.
5. Data 에 매핑(`Components.Schemas.<Name>+Domain.swift`)과 Repository 호출을 추가한다.
6. 명세와 `Sources/Generated/` 를 함께 커밋한다.

커밋된 생성물이 명세와 같은지는 다음 명령으로 확인한다. 다르면 exit 1 로 끝난다.

```bash
Scripts/openapi-generate.sh --check
```

생성기 버전은 `mise.toml` 에 고정되어 있다. `mise install` 로 설치한다.

### 테스트

- Repository 테스트는 `APIProtocol` 을 채택한 스텁을 테스트 파일 안에 두고, 원하는 `Output` 을 돌려준다.
  쓰지 않는 operation 은 `Issue.record` 후 에러를 던지게 둔다.
- 토큰 저장소가 필요하면 `NetworkingTesting` 의 `InMemoryTokenStore` 를 쓴다. `saveCount`, `clearCount` 로 호출을 확인할 수 있다.

## 동작 세부

### 미들웨어 순서

`Logging → Retry → Auth → transport` 순서다. 배열 앞쪽이 바깥쪽이다.

- Logging 이 가장 바깥이라 재시도를 포함한 전체 소요 시간이 한 줄로 남는다.
- Auth 가 Retry 안쪽이라 재시도할 때마다 최신 토큰이 다시 붙는다.
- refresh 요청은 Logging 만 붙은 별도 클라이언트로 보낸다. Auth 를 다시 타지 않는다.

### 세션 설정 (`NetworkDefaults`)

| 항목 | 값 | 의미 |
|---|---|---|
| 요청 타임아웃 | 15초 | 데이터가 오가지 않은 채 기다리는 최대 시간 |
| 리소스 타임아웃 | 30초 | 요청 하나의 전체 시간 상한 |
| `waitsForConnectivity` | `false` | 오프라인이면 기다리지 않고 바로 실패 |
| 재시도 | 2회, 0.5초부터 2배 | 멱등 요청만 |

화면에서 기다리는 요청을 기준으로 한 값이다. 연결을 기다려야 하는 백그라운드 작업이 생기면 그 작업용 세션을 따로 만든다.

## 주의

- `Sources/Generated/*.generated.swift` 는 손으로 고치지 않는다. lint/format 대상에서도 빠져 있다.
- 로그에 헤더, 토큰, 바디, 쿼리 문자열을 남기지 않는다.
- `TokenRefresher` 는 저장에 실패한 새 토큰을 메모리에 들고 저장소보다 먼저 읽는다.
  로그인·로그아웃처럼 `TokenStore` 에 직접 쓰는 코드를 추가할 때는 `TokenRefresher` 를 거치거나 그 메모리 값을 비우는 진입점을 함께 만든다.
  그러지 않으면 새로 저장한 토큰이나 로그아웃 결과가 가려진다.
