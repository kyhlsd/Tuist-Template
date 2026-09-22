# 네트워크 계층 재구성 (OpenAPI 생성 클라이언트 + JWT 두 토큰 인증)

## 목표

- 서버 API는 `Modules/Core/Networking/OpenAPI/openapi.yaml` 한 파일로 기술한다.
  `Scripts/openapi-generate.sh` 한 번이면 Swift 클라이언트(`*.generated.swift`)가 다시 만들어진다.
  `Scripts/openapi-generate.sh --check`는 커밋된 생성물이 명세와 다르면 0이 아닌 코드로 끝난다.
- 명세는 아직 서버에 없으므로 **임시 명세**로 시작한다. 이 명세에는 `GET /items`, `POST /auth/login`, `POST /auth/refresh`가 들어간다.
  나중에 실제 명세로 바꿔도 생성 스크립트를 다시 돌리고 Data 쪽 매핑만 고치면 된다.
- 요청에는 `Authorization: Bearer <access token>`이 자동으로 붙는다(공개 operation 제외).
- 401을 받으면 refresh token으로 한 번 갱신하고 원 요청을 한 번 재시도한다.
  **동시에 401이 여러 개 와도 refresh 호출은 한 번뿐이다.**
- refresh가 401/400으로 거절되면 토큰을 지우고 세션 만료 콜백을 한 번 호출한다.
- 토큰은 Keychain에 저장한다.
- 멱등 요청(GET/HEAD/PUT/DELETE)은 일시적 실패(연결 끊김, 호스트 연결 실패, 502/503) 시 지수 백오프로 최대 2회 재시도한다.
  타임아웃(클라이언트 `.timedOut`, 게이트웨이 504)은 재시도하지 않는다(리뷰 R1-8, 2라운드 번복: 이미 타임아웃만큼 기다린 결과라 재시도하면 대기가 몇 배로 늘어난다).
- 요청 로그는 `os.Logger`로 남긴다. method, path, status, 소요 시간만 남기고 헤더와 바디는 남기지 않는다.
- 기존 예시 코드(`HTTPClient`, `URLSessionHTTPClient`, `NetworkError`, `ItemDTO`)는 삭제한다. `RemoteItemRepository`는 생성된 `APIProtocol`을 쓰도록 바꾼다.
- Home 화면의 항목 목록은 기존과 같이 동작한다(Feature 코드 변경 없음).
- `./.claude/scripts/xcbuild.sh test` 통과.

## 범위 밖

- 로그인 화면, `AuthRepository`/로그인 UseCase, 로그아웃 UI. 로그인 API는 명세에만 있고 호출하는 코드는 없다.
- 세션 만료 시 화면 전환. App은 콜백을 받아 로그만 남긴다.
- JWT `exp`를 읽어 만료 전에 미리 갱신하는 선제 갱신. 이번에는 401 기반 반응형 갱신만 한다.
- 인증서 피닝, ATS 예외, 백그라운드 세션, 업로드·다운로드·스트리밍.
- `NWPathMonitor` 기반 네트워크 상태 감시.
- 서버 명세 확정. 임시 명세의 필드는 가정이다.
- CI 구성. `--check` 스크립트만 만들고 CI 연결은 하지 않는다.

## 전제

### 환경
- iOS 17.0, Swift 6 언어 모드(`Tuist/ProjectDescriptionHelpers/AppConstants.swift:23`, `Settings+Common.swift`의 `SWIFT_VERSION 6.0`).
- Tuist 4.208.0, 도구 버전은 `mise.toml`에 고정한다. `Tuist.swift`에서 `enforceExplicitDependencies: true`이다.
  → **각 타깃이 import하는 외부 모듈은 모두 `.external(name:)`으로 명시해야 한다.**
- 현재 외부 SPM 의존성은 0개(`Tuist/Package.swift`)이고 `Tuist/Package.resolved`가 없다. 이번에 처음 생긴다. `.gitignore` 주석대로 `Package.resolved`는 커밋한다.
- `.claude/scripts/xcbuild.sh`는 `tuist install`/`tuist generate`를 하지 않는다.
  의존성이나 매니페스트를 바꾼 단계에서는 `mise exec -- tuist install`, `mise exec -- tuist generate --no-open`을 먼저 돌린다.
- `**/*.generated.swift`는 SwiftLint(`.swiftlint.yml` excluded)와 SwiftFormat(`.swiftformat --exclude`)에서 이미 제외되어 있고, CLAUDE.md는 이 파일의 편집을 금지한다.
  → 생성 파일은 스크립트가 반드시 `*.generated.swift` 이름으로 바꿔 저장한다. 손으로 고치지 않는다.
- Networking 모듈은 `Project.core(name: "Networking")`(`Modules/Core/Networking/Project.swift`)이고 기본 격리가 없다(`.common`). 이 설정을 유지한다.

### 현재 코드 (변경 지점)
| 파일:줄 | 현재 | 이번 변경 |
|---|---|---|
| `Modules/Core/Networking/Sources/HTTPClient.swift:11` | `protocol HTTPClient` | 삭제 |
| `Modules/Core/Networking/Sources/URLSessionHTTPClient.swift:9` | URLSession 래퍼 | 삭제 |
| `Modules/Core/Networking/Sources/NetworkError.swift:12` | 전송 에러 enum | 삭제 |
| `Modules/Core/Networking/Tests/URLSessionHTTPClientTests.swift` | `validate(_:)` 테스트 | 삭제 |
| `Modules/Core/Networking/Project.swift` | `Project.core(name: "Networking")` | 외부 의존성 추가, `hasTestingSupport: true` |
| `Modules/Core/Data/Sources/RemoteItemRepository.swift:15` | `any HTTPClient` + `JSONDecoder` + `ItemDTO` | `any APIProtocol` 주입, `listItems()` 결과를 switch |
| `Modules/Core/Data/Sources/ItemDTO.swift` | DTO | 삭제. `Components.Schemas.Item` → `Item` 매핑 확장으로 대체 |
| `Modules/Core/Data/Tests/RemoteItemRepositoryTests.swift:48` | 파일 안의 `private struct` HTTPClient 스텁 | 파일 안의 `private struct` APIProtocol 스텁으로 교체(기존 관례 유지) |
| `Modules/Core/Data/Project.swift` | `.module(.domain)`, `.module(.networking)` | 필요하면 `.external(name: "OpenAPIRuntime")` 추가(구현 중 확인) |
| `App/Sources/DI/AppContainer.swift:19-21` | `URLSessionHTTPClient(session: .shared)` | 전용 `URLSession`, `KeychainTokenStore`, `APIClientFactory.make(...)`로 조립 |
| `App/Sources/DI/AppConfiguration.swift` | `apiBaseURL`만 있음 | 변경 없음. Keychain 서비스 이름은 `Bundle.main.bundleIdentifier`에서 얻는다 |
| `Modules/Core/Domain/Sources/ItemError.swift` | `.unavailable`, `.invalidData` | 변경 없음 |
| `Tuist/ProjectDescriptionHelpers/Module.swift:14-30` | 의존 방향 주석 | Networking → 외부 OpenAPI 패키지 추가 반영 |
| `Tuist/Package.swift` | 의존성 없음 | OpenAPI 런타임 3종 추가 |
| `mise.toml` | tuist, swiftformat, swiftlint | `spm:apple/swift-openapi-generator` 추가 |

### 쓰기로 한 패키지·도구 (2026-09-22 확인)
| 이름 | 버전 | 최소 플랫폼 | 용도 |
|---|---|---|---|
| swift-openapi-generator (CLI) | 1.13.1 | 개발 머신(macOS)만 | 명세 → Swift 코드. **빌드에 포함하지 않는다** |
| swift-openapi-runtime (`OpenAPIRuntime`) | 1.12.1 | iOS 13 | `ClientMiddleware`, `HTTPBody`, `ClientError` |
| swift-openapi-urlsession (`OpenAPIURLSession`) | 1.3.1 | iOS 13 | `URLSessionTransport` |
| swift-http-types (`HTTPTypes`) | 1.8.0 | — | `HTTPRequest`, `HTTPResponse`, `HTTPField.Name.authorization` |

- 세 패키지의 `swift-tools-version`은 6.1이다. Xcode 27 툴체인이면 문제없다. `Tuist/Package.swift`는 6.0 그대로 둔다.
- 셋 다 iOS 13 이상이라 **iOS 17에서 폴백이 필요 없다**.
- `mise ls-remote spm:apple/swift-openapi-generator`로 1.13.1이 설치 가능한 것을 확인했다.
- 생성기 설정 파일 `openapi-generator-config.yaml`의 키는 `generate`(`types`, `client`), `accessModifier`, `namingStrategy`, `filter`이다.
- 생성물은 9개 파일이다(`Types.swift`, `Types+Operations.swift`, `Types+Components*.swift` 6개, `Client.swift`. 구현 중 확인). `APIProtocol`(operation마다 메서드 하나), `Client: APIProtocol`, `Components.Schemas.*`, `Operations.*`가 나뉘어 들어 있다.
  생성기 CLI에는 `--version` 옵션이 없다. 설치 버전은 `mise ls spm:apple/swift-openapi-generator`로 확인한다.
  operation 결과는 `Output` enum이다(`.ok(...)`, 명세에 적은 상태, `.undocumented(statusCode:_:)`).

### 설계 근거가 된 조사 결과
- 원래 플랫폼 조사는 **무의존 자체 구현**을 권했다. 사용자가 OpenAPI를 써보기로 결정했으므로 이를 뒤집었다(아래 "결정 사항" 참고).
  자체 구현안의 핵심(actor로 refresh 단일화, 미들웨어 체인)은 그대로 `ClientMiddleware` 위로 옮겨 쓴다.
- Tuist의 `Tuist/Package.swift` 통합(XcodeProj 기반)은 SwiftPM **빌드 도구 플러그인**을 지원하지 않는다. Xcode 네이티브 패키지 통합(`Project(packages:)` + `.package(product:type: .plugin)`)으로만 된다.
  그래서 CLI로 생성하고 결과를 커밋하는 방식을 택했다.
- `URLSession.shared`는 설정을 바꿀 수 없다 → 전용 세션을 만들어 주입한다. 이 세션은 앱 수명 동안 한 개만 두고 `AppContainer`가 소유한다.
- 요청이 취소되면 `URLError(.cancelled)`나 `CancellationError`가 난다. 이 에러는 재시도하지 않고, refresh도 트리거하지 않는다.
- actor는 재진입할 수 있다. refresh `Task`를 저장하는 일은 반드시 `await` **이전에** 동기적으로 끝낸다.
- `HTTPBody`의 `iterationBehavior`가 `.single`이면 한 번만 읽을 수 있다. 재전송(401 재시도, 일시 실패 재시도)은 body가 `nil`이거나 `.multiple`일 때만 한다.
  JSON 바디는 생성 코드가 `Data`로 만들기 때문에 `.multiple`이다.

### 알려진 함정
- 생성 코드는 `public`으로 만든다(`accessModifier: public`). Data가 다른 모듈에서 `APIProtocol`과 `Components`를 쓰기 때문이다.
- 미들웨어 배열은 앞쪽이 바깥쪽이다. 요청은 첫 미들웨어가 가장 먼저 받는다.
  순서는 `[LoggingMiddleware, RetryMiddleware, AuthMiddleware]`로 정한다. 재시도할 때마다 Auth가 최신 토큰을 다시 붙이게 하기 위해서다.
- 로그에 `Authorization` 헤더, 토큰, 요청·응답 바디를 절대 남기지 않는다. 경로도 `privacy: .public`은 path에만 적용하고, 쿼리는 남기지 않는다.
- Keychain API(`SecItem*`)는 디스크에 닿는다. 테스트 규칙(`.claude/rules/tests.md`)상 단위 테스트를 만들지 않는다. 테스트에는 `InMemoryTokenStore`를 쓴다.

## 결정 사항
| 결정 | 선택 | 이유 |
|---|---|---|
| 클라이언트 구현 방식 | swift-openapi-generator 생성 클라이언트 + `ClientMiddleware` | 사용자가 명세 주도 방식을 써보기로 결정. 명세가 곧 계약이 되고 타입 불일치가 컴파일 단계에서 잡힌다 |
| 생성 시점 | CLI로 생성해 커밋(빌드 플러그인 미사용) | Tuist XcodeProj 통합은 빌드 플러그인을 지원하지 않는다. 플러그인 신뢰 프롬프트, `-skipPackagePluginValidation`, 패키지 통합 방식 혼용을 피한다. 누락은 `--check`로 막는다 |
| 생성기 버전 고정 | `mise.toml`의 `"spm:apple/swift-openapi-generator" = "1.13.1"` | 기존 도구와 같은 방식. 버전이 다르면 생성물이 달라진다 |
| 생성물 위치·이름 | `Modules/Core/Networking/Sources/Generated/*.generated.swift`(생성기가 만든 `.swift` 전부를 이름만 바꿔 저장) | 기존 lint/format 제외 규칙과 "편집 금지" 규칙을 그대로 적용받는다 |
| 명세 위치 | `Modules/Core/Networking/OpenAPI/openapi.yaml` + `openapi-generator-config.yaml` | 생성물을 소유한 모듈 옆에 둔다 |
| 모듈 배치 | 생성 코드, 미들웨어, 토큰 저장소, 팩토리를 모두 Networking 한 모듈에 둔다 | 새 모듈을 만들 만큼 크지 않다. Feature는 여전히 Networking을 모른다 |
| Data가 의존하는 타입 | 생성된 `APIProtocol`(구체 `Client` 아님) | 규약상 프로토콜 의존. 테스트에서 스텁으로 바꾸기 쉽다 |
| 생성 모델의 노출 범위 | `Components.Schemas.*`는 Data에서 Domain 모델로 매핑하고 그 위로 올리지 않는다 | 서버 명세가 바뀌어도 Domain과 Feature는 영향받지 않는다 |
| 인증 방식 | Access/Refresh JWT 두 토큰. 401 발생 시 반응형으로 갱신 | 사용자 지정. 선제 갱신은 범위 밖 |
| refresh 단일화 | `actor TokenRefresher`가 진행 중인 `Task<AuthTokens, any Error>`를 공유 | 동시 401을 refresh 한 번으로 모은다 |
| "이미 갱신됨" 판정 | 401을 받은 요청이 쓴 access token과 저장소의 현재 토큰이 다르면 네트워크 호출 없이 현재 토큰을 반환 | refresh가 끝난 직후 도착한 늦은 401이 refresh를 다시 일으키지 않게 한다 |
| refresh 호출 경로 | AuthMiddleware가 없는 별도 `Client` 인스턴스(Logging만 붙임) | refresh 요청이 AuthMiddleware를 다시 타서 재귀하는 것을 막는다 |
| 공개 operation | `PublicOperation` enum에 `login`, `refreshToken` operationId를 모아 두고 Auth가 건너뛴다 | 로그인 실패(401)가 refresh를 일으키지 않게 한다 |
| refresh 실패 처리 | 401/400이면 토큰을 지우고 `onSessionExpired`를 호출한 뒤 `AuthenticationError.sessionExpired`를 던진다. 전송 실패면 토큰을 유지하고 에러만 전파 | 일시적인 네트워크 문제로 로그아웃되지 않게 한다 |
| 토큰 저장 | `protocol TokenStore: Sendable` + `KeychainTokenStore`(`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) | 백그라운드에서도 읽을 수 있고, 기기 백업으로 다른 기기에 넘어가지 않는다 |
| 에러 타입 | Networking 공개 에러 `AuthenticationError`(`.sessionExpired`, `.refreshFailed`)만 신설. 나머지는 `ClientError`를 Data에서 `ItemError`로 매핑 | 계층마다 자기 에러만 안다는 기존 원칙 유지. Domain 변경 없음 |
| typed throws | 생성 코드와 미들웨어는 `throws`(런타임 프로토콜 시그니처). Repository는 기존 `throws(ItemError)` 유지 | `ClientMiddleware`가 untyped라 따라간다 |
| 재시도 정책 | 멱등 메서드만, 최대 2회, 지연 0.5초·1초. `sleep`은 주입받는다 | 테스트에서 시계에 의존하지 않기 위해서다 |
| URLSession 설정 | 전용 `URLSessionConfiguration.default`. `timeoutIntervalForRequest` 15초, `timeoutIntervalForResource` 30초, `waitsForConnectivity = false` | 화면에서 기다리는 요청이다. 오프라인이면 바로 실패하고 화면의 "다시 시도"로 다시 부른다(1라운드 뒤 사용자 결정. 처음 값 30초/60초/true는 오프라인에서 60초를 기다렸다). 값은 `enum NetworkDefaults`에 모은다 |
| 테스트 더블 공유 | `NetworkingTesting` 타깃 신설(`InMemoryTokenStore`) | 기존 `DomainTesting` 관례. Data와 App 테스트에서 재사용한다 |

## 변경 계획
각 단계는 독립적으로 빌드가 통과해야 하고, 커밋 하나 분량이다. `main`에 직접 커밋할 수 없으므로 먼저 `feat/openapi-networking` 브랜치를 만든다.

### 1. 생성기 도구와 스크립트
- 파일: `mise.toml`, `Scripts/openapi-generate.sh`(신규, 실행 권한)
- 변경:
  - `mise.toml`의 `[tools]`에 `"spm:apple/swift-openapi-generator" = "1.13.1"`을 추가한다. 기존 주석 스타일대로 한 줄 이유를 단다.
  - 스크립트 동작(`set -euo pipefail`, 저장소 루트 기준 경로):
    1. 임시 디렉터리에 `mise exec -- swift-openapi-generator generate --config <config> --output-directory <tmp> <openapi.yaml>`을 실행한다.
    2. 생성된 `*.swift`를 모두 `*.generated.swift`로 이름을 바꾼다(예: `Types+Components.swift` → `Types+Components.generated.swift`).
    3. 기본 모드에서는 `Sources/Generated/`로 옮긴다. `--check` 모드에서는 `diff -r`로 비교하고, 다르면 안내 메시지와 함께 `exit 1` 한다.
  - `Workspace.swift`의 `additionalFiles`에 `"Scripts/**"`를 넣을지는 선택이다(넣으면 Xcode에서 보인다).
- 검증: `mise install` 성공, `mise ls spm:apple/swift-openapi-generator`가 1.13.1을 표시. 명세가 없으므로 스크립트가 명세 누락을 알리는 에러로 끝나는지 확인.

### 2. 외부 패키지 추가
- 파일: `Tuist/Package.swift`, `Tuist/Package.resolved`(생성, 커밋), `Modules/Core/Networking/Project.swift`
- 변경:
  - `dependencies`에 세 패키지를 추가한다. `.package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.12.1")`, `swift-openapi-urlsession` `from: "1.3.1"`, `swift-http-types` `from: "1.8.0"`.
    예시 주석은 지운다. `productTypes`는 기본값(static framework)을 유지한다.
  - Networking에 `dependencies: [.external(name: "OpenAPIRuntime"), .external(name: "OpenAPIURLSession"), .external(name: "HTTPTypes")]`와 `hasTestingSupport: true`를 넣는다.
    테스트 타깃에는 `testDependencies`로 `OpenAPIRuntime`, `HTTPTypes`를 넣는다(미들웨어 테스트가 import한다).
  - 이 단계에서 `hasTestingSupport`를 켜면 `Testing/Sources/**`가 비어 있어 빌드가 실패할 수 있다. 그렇다면 이 옵션은 4단계로 미룬다(구현 중 확인).
- 검증: `mise exec -- tuist install` → `mise exec -- tuist generate --no-open` → `xcbuild.sh build` 성공.
  - **구현 중 확인:** swift-openapi-urlsession이 `traits: []`로 runtime을 참조한다. Tuist 4.208의 XcodeProj 통합이 이 패키지 traits를 처리하는지 확인한다.
    실패하면 오류 라인을 계획 문서 "위험 요소"에 적고 멈춘다.

### 3. 임시 명세와 첫 생성
- 파일: `Modules/Core/Networking/OpenAPI/openapi.yaml`(신규), `Modules/Core/Networking/OpenAPI/openapi-generator-config.yaml`(신규), `Modules/Core/Networking/Sources/Generated/*.generated.swift`(생성물 9개)
- 변경:
  - `openapi: 3.1.0`, `info.title`, `servers`는 비워 둔다(base URL은 런타임에 주입).
  - `components.securitySchemes.bearerAuth`(http bearer, JWT)와 전역 `security: [bearerAuth: []]`를 넣는다. login·refresh operation에는 `security: []`를 넣는다(문서 목적. 코드 동작은 `PublicOperation`이 결정).
  - operation:
    - `GET /items`: `operationId: listItems`. 200은 `Item` 배열, 401은 `ErrorResponse`.
    - `POST /auth/login`: `operationId: login`. body `LoginRequest { email, password }`. 200은 `TokenPair`, 401은 `ErrorResponse`.
    - `POST /auth/refresh`: `operationId: refreshToken`. body `RefreshRequest { refreshToken }`. 200은 `TokenPair`, 400·401은 `ErrorResponse`.
  - schema:
    - `Item { id: string, title: string }`. 기존 `ItemDTO`와 같은 필드다.
    - `TokenPair { accessToken: string, refreshToken: string }`
    - `ErrorResponse { code: string, message: string }`
  - config: `generate: [types, client]`, `accessModifier: public`, `namingStrategy: idiomatic`.
  - 파일 맨 위 주석에 "임시 명세, 서버 명세 확정 시 교체"를 적는다.
  - `Scripts/openapi-generate.sh`를 실행해 생성물을 커밋한다.
- 검증: `xcbuild.sh build` 성공(Swift 6 언어 모드에서 생성 코드가 컴파일됨), `Scripts/openapi-generate.sh --check` 종료 코드 0.
  - **구현 중 확인:** 생성 코드가 Swift 6 엄격 동시성에서 에러 없이 컴파일되는지 확인한다. 실패하면 "위험 요소" 표의 대응을 따른다.
  - **구현 중 확인:** `namingStrategy: idiomatic`에서 실제 생성된 메서드와 케이스 이름(`listItems`, `refreshToken`, `.ok`, `.unauthorized`, `.badRequest`)을 확인하고, 이후 단계의 이름을 거기에 맞춘다.

### 4. 토큰 모델과 저장소
- 파일(모두 `Modules/Core/Networking/` 아래):
  - `Sources/Auth/AuthTokens.swift`: `public struct AuthTokens: Sendable, Equatable { accessToken, refreshToken }`. 생성 타입 `Components.Schemas.TokenPair`와 분리한 앱 내부 모델이다.
  - `Sources/Auth/TokenStore.swift`: `public protocol TokenStore: Sendable`. `func load() async throws -> AuthTokens?`, `func save(_:) async throws`, `func clear() async throws`.
  - `Sources/Auth/KeychainTokenStore.swift`: `public struct`. `init(service: String)`.
    두 토큰을 JSON 하나로 묶어 generic password 항목 1개에 저장한다(account 키는 `enum` 상수).
    저장은 `SecItemUpdate`를 먼저 시도하고, `errSecItemNotFound`면 `SecItemAdd`를 쓴다. 삭제 시 `errSecItemNotFound`는 성공으로 본다(한 줄 주석).
  - `Sources/Auth/KeychainError.swift`: `public enum KeychainError: Error { case unexpectedStatus(OSStatus), invalidData }`
  - `Testing/Sources/InMemoryTokenStore.swift`: `public actor InMemoryTokenStore: TokenStore`. 초기 토큰을 주입받고, 테스트 검증용으로 `saveCount`, `clearCount`를 기록한다.
- 검증: 빌드 성공. Keychain 구현은 디스크 의존이라 단위 테스트를 만들지 않는다(테스트 전략 참고).

### 5. TokenRefresher
- 파일: `Modules/Core/Networking/Sources/Auth/TokenRefresher.swift`, `Sources/Auth/AuthenticationError.swift`, `Tests/TokenRefresherTests.swift`
- 변경:
  - `public enum AuthenticationError: Error, Equatable, Sendable { case sessionExpired, refreshFailed }`
  - `actor TokenRefresher`(internal):
    - `init(store: any TokenStore, refresh: @escaping @Sendable (String) async throws -> AuthTokens, onSessionExpired: @escaping @Sendable () async -> Void)`
    - `func currentAccessToken() async throws -> String?`: 저장소에서 읽는다.
    - `func refreshedAccessToken(rejected: String?) async throws -> String` 흐름:
      1. `inFlight`가 있으면 그 `Task`를 `await`해서 반환한다.
      2. 없으면 저장소의 현재 토큰을 읽는다. 없으면 `sessionExpired`를 던지기만 한다(삭제·콜백 없음. 로그인 전이거나 만료 처리가 이미 끝난 상태이고, 늦게 도착한 401이 콜백을 다시 부르지 않게 하기 위해서다).
         현재 access token이 `rejected`와 다르면 그 토큰을 바로 반환한다.
      3. 같으면 `Task`를 만들어 `inFlight`에 **await 없이** 저장한다. 그 Task는 refresh 호출 → `store.save` 순서로 동작한다.
      4. Task를 await한 뒤 성공이든 실패든 `inFlight = nil`로 비운다.
    - 2단계의 저장소 읽기는 `await`라서 그 사이에 다른 호출이 끼어들 수 있다. 3단계 직전에 `inFlight`를 다시 확인한다(재진입 대비).
    - refresh 클로저가 `AuthenticationError.sessionExpired`를 던지면 `store.clear()` 후 `onSessionExpired()`를 **한 번만** 호출하고 다시 던진다.
      같은 Task를 기다리던 호출자들은 같은 에러를 받을 뿐 콜백을 중복 호출하지 않는다. 그 밖의 에러는 저장소를 건드리지 않고 전파한다.
- 검증: `xcbuild.sh test -only-testing:NetworkingTests/TokenRefresherTests` 통과.

### 6. AuthMiddleware
- 파일: `Modules/Core/Networking/Sources/Middleware/AuthMiddleware.swift`, `Sources/Middleware/PublicOperation.swift`, `Tests/AuthMiddlewareTests.swift`
- 변경:
  - `enum PublicOperation { static let ids: Set<String> = ["login", "refreshToken"] }`. 값은 명세의 operationId와 같아야 한다.
  - `struct AuthMiddleware: ClientMiddleware`(internal). `init(refresher: TokenRefresher, publicOperationIDs: Set<String>)`.
  - `intercept` 흐름:
    1. `operationID`가 공개 목록에 있으면 그대로 `next`를 호출한다.
    2. `currentAccessToken()`이 있으면 `request.headerFields[.authorization] = "Bearer \(token)"`을 붙여 호출한다.
    3. 응답이 401이 아니면 그대로 반환한다.
    4. 401이고 body가 `nil`이거나 `iterationBehavior == .multiple`이면 `refreshedAccessToken(rejected: 사용한 토큰)`으로 새 토큰을 받는다. 헤더를 교체해 **한 번만** 재호출한다.
       body가 `.single`이면 원래 401 응답을 반환한다.
    5. 재호출도 401이면 그 응답을 그대로 반환한다(루프 금지).
  - `"Bearer "` 접두어는 `enum` 상수로 둔다.
- 검증: `-only-testing:NetworkingTests/AuthMiddlewareTests` 통과.

### 7. RetryMiddleware와 LoggingMiddleware
- 파일: `Sources/Middleware/RetryMiddleware.swift`, `Sources/Middleware/LoggingMiddleware.swift`, `Tests/RetryMiddlewareTests.swift`
- 변경:
  - `RetryMiddleware`:
    - `init(maxRetries: Int, baseDelay: Duration, sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) })`
    - 재시도 조건(모두 만족해야 함):
      - method가 GET/HEAD/PUT/DELETE다.
      - body가 `nil`이거나 `.multiple`이다.
      - `next`가 `.networkConnectionLost`, `.cannotConnectToHost`인 `URLError`를 던졌거나, 응답 status가 502/503이다. 504는 제외한다(2라운드 번복).
        런타임은 transport 에러를 `ClientError`로 감싸 `next` 밖으로 던지므로 `underlyingError`를 꺼내 판단한다(리뷰 R1-1). `.timedOut`은 제외한다(R1-8).
    - 지연은 `baseDelay * 2^attempt`이다. `CancellationError`, `URLError(.cancelled)`는 즉시 다시 던진다. 매 시도 전에 `Task.checkCancellation()`을 호출한다.
    - 마지막 시도의 결과(응답 또는 에러)를 그대로 돌려준다.
  - `LoggingMiddleware`:
    - `Logger(subsystem:category:)`의 subsystem은 주입받는다(하드코딩 금지). 시작 시각은 `ContinuousClock`으로 잰다.
    - 성공하면 `debug`로 `method path status 소요ms`를 남기고, 에러면 `error`로 남긴 뒤 다시 던진다.
    - path는 `request.path`에서 `?` 앞부분만 쓴다. 헤더와 바디는 기록하지 않는다.
- 검증: `-only-testing:NetworkingTests/RetryMiddlewareTests` 통과. Logging은 출력을 관찰할 수 없어 에러 요약 규칙(`summary(of:)`)만 `LoggingMiddlewareTests`로 고정한다(리뷰 R2-2).

### 8. APIClientFactory
- 파일: `Sources/APIClientFactory.swift`, `Sources/NetworkDefaults.swift`
- 변경:
  - `enum NetworkDefaults`에 요청 타임아웃 15초, 리소스 타임아웃 30초, `waitsForConnectivity = false`, 재시도 2회, 기본 지연 0.5초를 모은다. `static func makeSessionConfiguration() -> URLSessionConfiguration`을 둔다.
  - `public enum APIClientFactory`:
    - `static func make(baseURL: URL, session: URLSession, tokenStore: any TokenStore, logSubsystem: String, onSessionExpired: @escaping @Sendable () async -> Void) -> any APIProtocol`
    - 내부 조립:
      1. `transport = URLSessionTransport(configuration: .init(session: session))`
      2. `refreshClient = Client(serverURL: baseURL, transport:, middlewares: [logging])`
      3. refresh 클로저를 만든다. `refreshClient.refreshToken(body: .json(.init(refreshToken:)))`를 호출하고 결과를 매핑한다.
         `.ok` → `AuthTokens`, `.unauthorized`/`.badRequest` → `AuthenticationError.sessionExpired`, 그 밖(`.undocumented`) → `.refreshFailed`.
      4. `TokenRefresher`를 만든다.
      5. `Client(serverURL: baseURL, transport:, middlewares: [logging, retry, auth])`를 반환한다.
  - 생성된 `Client`의 init 시그니처(`configuration:` 인자 등)는 **구현 중 확인**한다.
- 검증: 빌드 성공.

### 9. Data·App 이전과 예시 코드 삭제
- 파일:
  - 삭제: `Modules/Core/Networking/Sources/{HTTPClient,URLSessionHTTPClient,NetworkError}.swift`, `Modules/Core/Networking/Tests/URLSessionHTTPClientTests.swift`, `Modules/Core/Data/Sources/ItemDTO.swift`
  - 수정: `Modules/Core/Data/Sources/RemoteItemRepository.swift`, `Modules/Core/Data/Tests/RemoteItemRepositoryTests.swift`, `Modules/Core/Data/Project.swift`, `App/Sources/DI/AppContainer.swift`
  - 신규: `Modules/Core/Data/Sources/Components.Schemas.Item+Domain.swift`. 파일명 규칙은 기존 `Item+Fixtures.swift` 관례를 따른다.
- 변경:
  - `RemoteItemRepository`:
    - `init(client: any APIProtocol)`. `baseURL`은 팩토리로 옮겨가므로 뺀다.
    - `fetchItems()`는 `try await client.listItems()`를 호출한다.
      - `.ok(let ok)` → `try ok.body.json`을 `toDomain()`으로 매핑한다.
      - `.unauthorized`, `.undocumented` → `.unavailable`
    - 호출 자체가 던진 에러는 `.unavailable`로 바꾼다. 기존 주석("화면이 구분하지 않으므로")을 유지한다.
    - `.json` 접근이 던지는 에러(콘텐츠 타입 불일치)는 `.invalidData`로 바꾼다. 디코딩 실패는 생성 코드에서 `ClientError`로 오므로 `.unavailable`에 합쳐진다. 이 차이를 주석으로 남긴다.
  - `AppContainer.init`:
    - `URLSession(configuration: NetworkDefaults.makeSessionConfiguration())`로 세션을 만들어 프로퍼티로 소유한다. `NetworkDefaults`가 internal이면 팩토리에 `public static func makeSession()`을 둔다.
    - Keychain 서비스 이름은 `Bundle.main.bundleIdentifier`에서 얻는다. 없으면 `preconditionFailure`로 이유를 남긴다.
    - 로그 subsystem도 같은 값을 쓴다.
    - `onSessionExpired`에서는 `Logger`로 한 줄을 남긴다. 화면 전환이 범위 밖이라는 점을 주석으로 적는다.
  - `Data/Project.swift`:
    - 생성 타입의 `Output` 케이스나 `ClientError`에 접근하는 데 `OpenAPIRuntime` import가 필요하면 `dependencies`와 `testDependencies`에 `.external(name: "OpenAPIRuntime")`을 추가한다(구현 중 확인).
    - 테스트 주석("테스트 안의 HTTPClient 스텁")을 새 스텁에 맞게 고친다.
- 검증: `tuist generate` → `xcbuild.sh test` 전체 통과. 시뮬레이터에서 Home 목록 화면이 이전과 같이 뜨는지 확인한다. dev 서버가 없으면 에러 상태 화면이 나오는 것까지만 확인한다.

### 10. 문서
- 파일: `Tuist/ProjectDescriptionHelpers/Module.swift`(주석), `Modules/Core/Networking/README.md`(신규)
- 변경:
  - `Module.swift`의 의존 방향 그림에 `Networking ──→ OpenAPIRuntime, OpenAPIURLSession, HTTPTypes(외부)`를 추가한다.
  - `.networking` case에 "생성 클라이언트, 미들웨어, 토큰 저장소" 한 줄 설명을 단다.
  - README에는 다음을 적는다.
    - 명세 수정 → `Scripts/openapi-generate.sh` → 커밋 절차
    - `--check`의 용도
    - 공개 operation을 추가할 때 `PublicOperation.ids`도 고쳐야 한다는 점
    - 생성물 편집 금지
    - 미들웨어 순서와 이유
    - 임시 명세라는 사실
- 검증: `xcbuild.sh build` 성공, `Scripts/openapi-generate.sh --check` 종료 코드 0.

## 테스트 전략

모든 테스트는 Swift Testing이고 네트워크·디스크·시계에 의존하지 않는다.
미들웨어는 `intercept(_:body:baseURL:operationID:next:)`를 직접 호출하고, `next`는 호출 횟수와 받은 헤더를 기록하는 클로저로 대체한다.

| 테스트 | 검증하는 분기 |
|---|---|
| `TokenRefresherTests.refreshedAccessToken_concurrentCalls_refreshesOnce` | 5개 동시 호출 → refresh 클로저 1회, 모두 같은 토큰. refresh 클로저는 `CheckedContinuation`으로 붙잡아 두었다가 모든 호출이 들어온 뒤 풀어 준다(sleep 금지) |
| `TokenRefresherTests.refreshedAccessToken_rejectedTokenIsStale_returnsCurrentWithoutRefresh` | 저장소 토큰 ≠ rejected → refresh 0회 |
| `TokenRefresherTests.refreshedAccessToken_success_savesNewTokens` | 저장소에 새 토큰 저장 |
| `TokenRefresherTests.refreshedAccessToken_sessionExpired_clearsStoreAndNotifiesOnce` | 동시 3개 호출 + sessionExpired → clear 1회, 콜백 1회, 3개 모두 에러 |
| `TokenRefresherTests.refreshedAccessToken_transportFailure_keepsTokens` | URLError → clear 0회, 에러 전파 |
| `TokenRefresherTests.refreshedAccessToken_noStoredTokens_throwsSessionExpired` | 저장소가 빈 경우 |
| `TokenRefresherTests.refreshedAccessToken_afterFailure_canRefreshAgain` | 실패 뒤 `inFlight`가 비워졌는지 |
| `AuthMiddlewareTests.intercept_withToken_attachesBearerHeader` | 헤더 부착 |
| `AuthMiddlewareTests.intercept_publicOperation_doesNotAttachHeader` | `login`/`refreshToken` 제외 |
| `AuthMiddlewareTests.intercept_unauthorized_refreshesAndRetriesOnce` | 401 → 새 토큰으로 재호출, next 2회 |
| `AuthMiddlewareTests.intercept_unauthorizedTwice_returnsSecondResponse` | 재시도도 401이면 루프 없이 반환, next 2회 |
| `AuthMiddlewareTests.intercept_unauthorizedWithSingleIterationBody_doesNotRetry` | `.single` body |
| `AuthMiddlewareTests.intercept_publicOperationUnauthorized_doesNotRefresh` | 로그인 실패가 refresh를 부르지 않음 |
| `RetryMiddlewareTests.intercept_transientErrorThenSuccess_retries` | timedOut → 성공, sleep 1회 |
| `RetryMiddlewareTests.intercept_serviceUnavailable_retriesUpToMax` | 503 연속 → next 3회, sleep 지연값이 0.5초·1초 |
| `RetryMiddlewareTests.intercept_postRequest_doesNotRetry` | 비멱등 메서드 |
| `RetryMiddlewareTests.intercept_cancelled_doesNotRetry` | `URLError(.cancelled)`, `CancellationError` (parameterized) |
| `RetryMiddlewareTests.intercept_clientError_doesNotRetry` | 404 → 1회 |
| `RemoteItemRepositoryTests.fetchItems_ok_mapsToDomain` | `.ok` 매핑 |
| `RemoteItemRepositoryTests.fetchItems_unauthorized_throwsUnavailable` | `.unauthorized` |
| `RemoteItemRepositoryTests.fetchItems_undocumented_throwsUnavailable` | `.undocumented` |
| `RemoteItemRepositoryTests.fetchItems_clientThrows_throwsUnavailable` | 호출 자체 실패 |

- 동시 호출 테스트는 `withThrowingTaskGroup`으로 만든다. refresh 클로저 안의 호출 횟수는 actor 카운터로 센다.
- Data 테스트 스텁은 `private struct StubAPI: APIProtocol`로 파일 안에 둔다. 명세의 operation이 늘면 스텁에 메서드를 추가해야 하므로, 쓰지 않는 메서드는 `Issue.record` 후 에러를 던지는 형태로 둔다.
  operation이 많아지면 `NetworkingTesting`으로 옮길지 그때 판단한다.
- 수정·삭제되는 기존 테스트:
  - `URLSessionHTTPClientTests.swift`는 삭제한다(대상 타입 삭제).
  - `RemoteItemRepositoryTests.swift`는 새 스텁으로 다시 쓴다.
  - Home 피처 테스트는 `DomainTesting`의 `StubItemRepository`를 쓰므로 영향이 없다.
- 테스트하지 않는 것:
  - `KeychainTokenStore`: 디스크 의존. 9단계 수동 실행에서 간접 확인한다.
  - `LoggingMiddleware`의 로그 출력 자체: 관찰 불가. 에러 요약 규칙만 테스트한다(R2-2).
  - `APIClientFactory`: 실제 transport 조립.

## 위험 요소
| 위험 | 가능성 | 대응 |
|---|---|---|
| Tuist 4.208 XcodeProj 통합이 swift-openapi-urlsession의 패키지 traits(`traits: []`)나 tools-version 6.1을 처리하지 못함 | 중 | 2단계에서 즉시 드러난다. 오류 라인을 기록하고 멈춘 뒤 사용자에게 알린다. 대안 1: `Tuist/Package.swift` tools-version을 6.1로 올린다. 대안 2: 해당 패키지만 Xcode 네이티브 통합(`Project(packages:)`)으로 옮긴다 |
| 생성 코드가 Swift 6 엄격 동시성에서 경고·에러를 냄 | 낮음 | 생성물은 편집 금지다. 생성기 버전을 올리거나 config의 `additionalImports`/`featureFlags`를 검토한다. 그래도 안 되면 생성물만 담은 별도 타깃을 Swift 5 모드로 두는 안을 사용자에게 묻는다(`.claude/rules/swift.md`와 충돌하므로 임의 적용 금지) |
| 명세 수정 후 생성 누락 | 중 | `--check` 스크립트와 README 절차. CI 연결은 후속 작업 |
| 임시 명세가 실제 서버와 달라 교체 시 Data 매핑이 대량 수정 | 중 | 생성 타입을 Data 밖으로 올리지 않는다. 영향 범위는 `RemoteItemRepository`와 매핑 확장뿐이다 |
| operationId 문자열(`PublicOperation.ids`)과 명세가 어긋나 로그인 실패가 refresh를 유발 | 중 | README 체크리스트, `AuthMiddlewareTests`에서 두 id를 명시적으로 검증 |
| actor 재진입으로 refresh 두 번 실행 | 중 | `inFlight` 저장을 await 이전에 끝내고, 저장소 읽기 뒤에 `inFlight`를 다시 확인. 동시 호출 테스트로 고정 |
| 오프라인·느린 서버에서 사용자 대기 | 중 | `waitsForConnectivity = false`라 오프라인은 즉시 실패한다. 서버가 멈춘 경우는 요청 15초·전체 30초로 상한이 있고, `.timedOut`은 재시도하지 않는다(R1-8). 백그라운드 작업이 생기면 그 작업용 세션에서만 켠다 |
| 외부 의존성 도입으로 빌드 시간·바이너리 증가 | 낮음 | 세 패키지 모두 작다. static framework 유지 |
| Keychain 접근 실패(잠금 상태 등)로 토큰 로드 에러 | 낮음 | `AfterFirstUnlockThisDeviceOnly`. `load()`가 던지면 요청은 토큰 없이 진행하지 않고 에러를 전파한다 |

## 롤백

- 단계별 커밋이므로 `git revert`로 되돌린다. 9단계를 되돌리면 예시 코드(`HTTPClient` 등)와 기존 `RemoteItemRepository`가 복원된다.
- 1~8단계는 추가만 한다. 9단계 이전까지는 기존 동작에 영향이 없다.
- 외부 의존성을 완전히 빼려면 2단계 revert 후 `mise exec -- tuist install && mise exec -- tuist generate --no-open`을 실행한다. `Tuist/Package.resolved`도 함께 삭제된다.
- iOS Keychain 항목은 앱을 지워도 남는다. 롤백 후 남은 토큰 항목이 문제가 되면 시뮬레이터를 초기화(Erase All Content and Settings)하거나 `SecItemDelete`로 한 번 정리한다.
