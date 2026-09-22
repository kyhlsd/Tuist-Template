# 리뷰 결정 기록 — `feat/openapi-networking`

리뷰어(`/ios-review`)는 검토 전에 이 문서를 읽고 "확정 결정"을 따릅니다.
확정 결정을 뒤집으려면 `번복 제안`으로만, 실패 시나리오와 함께 제안합니다.
구현(`/ios-implement`)은 리뷰를 반영한 뒤 이 문서를 갱신합니다.

- 대상: 네트워크 계층 재구성(OpenAPI 생성 클라이언트 + JWT 두 토큰 인증). 계획 `docs/plans/2026-09-22-openapi-networking.md`

## 확정 결정

**D1. 미들웨어는 런타임이 감싼 에러를 풀어서 판단한다**
- OpenAPIRuntime은 transport와 안쪽 미들웨어의 에러를 `ClientError`로 감싸 `next` 밖으로 던집니다(`UniversalClient.swift`의 `makeError`).
  에러 종류로 분기하는 미들웨어(Retry, Logging)는 `(error as? ClientError)?.underlyingError ?? error`로 원래 에러를 봅니다.
- 미들웨어 테스트의 `next` 대역도 실제처럼 `ClientError(underlyingError:)`를 던집니다. 날 에러를 던지면 이 경로가 검증되지 않습니다(R1-1).

**D2. 타임아웃은 재시도하지 않는다(클라이언트 `.timedOut`, 게이트웨이 504 모두)**
- 재시도 대상은 `.networkConnectionLost`, `.cannotConnectToHost`, 502/503입니다.
- 이유: `.timedOut`은 이미 타임아웃만큼 기다린 결과입니다. 재시도 2회를 붙이면 대기가 3배가 됩니다(지금 값이면 15초 × 3 ≈ 45초). 처음 설정(`waitsForConnectivity = true`, 리소스 60초)에서는 오프라인에서 최대 약 3분이었습니다(R1-8, 사용자 결정).
- 504도 같은 이유로 뺍니다. 게이트웨이가 upstream을 자기 타임아웃만큼 기다린 뒤 돌려주는 응답이라, 게이트웨이 타임아웃이 세션 상한(30초)보다 조금 짧으면(예: 29초) 재시도로 약 88초가 됩니다. 서버 게이트웨이 값과 관계없이 상한을 고정하려고 뺍니다(2라운드 번복 제안, 사용자 결정).

**D3. 저장된 토큰이 없으면 `sessionExpired`만 던진다**
- 토큰 삭제와 `onSessionExpired` 호출은 refresh가 400/401로 거절될 때 한 번만 합니다.
- 이유: 토큰이 없다는 건 로그인 전이거나 만료 처리가 이미 끝난 상태입니다. 여기서도 알리면 만료 뒤에 늦게 도착한 401마다 콜백이 다시 불립니다.

**D4. 토큰 저장소가 실패해도 인증 흐름은 계속된다**
- refresh 성공 뒤 `save`가 실패해도 새 토큰을 씁니다. 실패는 로그로 남깁니다.
  새 토큰은 `unsaved`로 메모리에 두고, 저장이 성공하거나 세션이 끝날 때까지 저장소보다 먼저 읽습니다(`loadTokens()`). 앱을 다시 시작하면 사라집니다(R2-1).
  기다리던 요청에만 쓰면 다음 요청이 이전 토큰으로 나가 401 → 이전 refresh token으로 갱신 → 거절 → 로그아웃이 한 요청 늦게 일어납니다.
  `unsaved`는 저장이 성공하거나 세션이 끝날 때 비웁니다. 두 분기 모두 테스트로 고정했습니다(R3-1).
  `unsaved`가 있는 동안에는 저장소를 읽지 않으므로, 저장소에 직접 쓰는 경로(로그인·로그아웃, 이번 범위 밖)를 만들 때는 `TokenRefresher`를 거치거나 `unsaved`를 비우는 진입점을 둡니다. 주석과 README에 적었고 로그인 작업 계획에서 이어받습니다(R3-2).
  이유: 서버가 refresh token을 교체했다면 이전 토큰은 이미 무효라, 새 토큰을 버리면 이번 요청도 실패하고 다음 갱신에서 세션이 만료됩니다(R1-6).
- 만료 처리에서 `clear`가 실패해도 `onSessionExpired`를 부르고 `sessionExpired`를 던집니다. 실패는 로그로 남깁니다.
  이유: 서버는 이미 세션을 거절했습니다. 남은 토큰은 다음 401에서 다시 거절되어 삭제가 재시도됩니다(R1-7).
- 로그는 `TokenRefresher`에 주입한 `Logger`로 남깁니다. 기본값은 `Logger(.disabled)`라서 테스트는 로거를 넘기지 않습니다.

**D5. refresh 응답 매핑은 `APIClientFactory.refreshTokens(using:refreshToken:)`에서 테스트한다**
- 이 함수는 `internal`이고 `any APIProtocol`을 받습니다. 400/401은 `sessionExpired`(토큰 삭제), 명세에 없는 응답은 `refreshFailed`(토큰 유지), 전송 실패는 그대로 던집니다(R1-2).
- 팩토리의 transport 조립 자체는 계속 테스트하지 않습니다.

**D6. 동시 refresh 테스트는 불변식만 검증한다**
- `refreshedAccessToken_concurrentCalls_refreshesOnce`는 "refresh 1회, 모두 새 토큰"만 봅니다. 나머지 호출이 진행 중인 Task에 합류했는지, "이미 갱신됨" 경로로 빠졌는지는 실행마다 다를 수 있습니다.
- 이유: 합류를 결정적으로 보려면 운영 코드인 `TokenRefresher`에 테스트용 확인 지점을 넣어야 합니다. 어느 경로로 가든 refresh가 두 번 불리면 테스트가 실패하므로, 지켜야 할 불변식은 고정됩니다(R1-9).

**D7. `ItemError.invalidData` 분기는 남긴다**
- 지금 명세의 200 본문은 JSON 하나뿐이라 이 분기는 실행되지 않습니다. 콘텐츠 타입 불일치와 디코딩 실패는 생성 코드가 `ClientError`로 던지므로 `unavailable`이 됩니다.
- 명세에 JSON이 아닌 콘텐츠 타입이 추가되면 이 분기가 실행됩니다. 주석을 이 동작에 맞췄고, Domain은 바꾸지 않습니다(R1-4).

**D8. 에러 로그는 원래 에러의 타입과 코드만 남긴다**
- `URLError`는 `URLError(<code>)`, 그 밖의 에러는 타입 이름만 남깁니다.
- 에러 설명은 남기지 않습니다. 쿼리가 붙은 URL이나 요청 헤더가 들어갈 수 있기 때문입니다(R1-5).

**D9. 세션은 화면용 설정이다: 요청 15초, 전체 30초, `waitsForConnectivity = false`**
- 오프라인이면 바로 `.notConnectedToInternet`으로 끝나고, Home의 "다시 시도"로 다시 부릅니다. 연결을 기다리는 동작은 백그라운드·비긴급 작업용 세션에서만 켭니다.
- 이유: 처음 설정은 오프라인에서 에러 화면이 뜨기까지 60초가 걸렸습니다(시뮬레이터에서 확인). 화면에서 기다리는 API로는 너무 깁니다(1라운드 뒤 사용자 결정).

## 라운드 이력

### 1라운드 — 스냅샷 `6142fbd7a6f0ab775cbbc0440eef924825c0d3b8`

| 항목 | 처리 | 이유 |
|---|---|---|
| R1-1 Retry가 `ClientError`로 감싼 `URLError`를 못 봄 | 반영 | `isTransient`에서 `underlyingError`를 꺼낸다(D1). 테스트 대역이 `ClientError`를 던지게 바꾸고, 마지막 시도의 일시 에러를 다시 던지는지 보는 테스트를 추가했다 |
| R1-2 refresh 응답 매핑 테스트 없음 | 반영 | `refreshTokens`를 `internal` + `any APIProtocol`로 바꿨다(D5). `APIClientFactoryTests`에 200 테스트 1개, 400/401/undocumented parameterized 테스트 1개 |
| R1-3 토큰 없음 분기 테스트 없음 | 반영 | 헤더 없이 보냄, 401이면 refresh 없이 `sessionExpired`이고 next 1회인지 확인하는 테스트 2개 |
| R1-4 `invalidData`에 도달할 수 없고 주석이 틀림 | 반영(Consider, 사용자 요청) | 주석을 실제 동작에 맞췄다. 분기는 남긴다(D7). 같은 패턴인 `refreshTokens`의 `.ok` 주석도 고쳤다 |
| R1-5 에러 로그가 늘 `ClientError` | 반영(Consider, 사용자 요청) | 원래 에러의 타입과 `URLError` 코드를 남긴다(D8) |
| R1-6 저장 실패 시 새 토큰을 버림 | 반영(Consider, 사용자 요청) | 새 토큰을 반환하고 로그를 남긴다(D4). 테스트 1개 |
| R1-7 삭제 실패 시 만료 알림 누락 | 반영(Consider, 사용자 요청) | 로그를 남기고 알림과 `sessionExpired`를 계속 진행한다(D4). 테스트 1개 |
| R1-8 타임아웃 재시도로 최대 약 3분 대기 | 반영(Consider, 사용자 결정) | `.timedOut`을 재시도에서 뺐다(D2). 계획 목표·7단계·위험 요소 표와 README를 고쳤다. 테스트 1개 |
| R1-9 동시 테스트가 합류 경로를 보장하지 않음 | 반영(Consider, 사용자 요청) | 확인 지점을 넣지 않고 테스트 설명을 불변식으로 좁혔다(D6) |
| R1-10 계획의 생성물 파일 수가 실제와 다름 | 반영(Consider, 사용자 요청) | 계획의 생성물 설명, 결정 표, 1·3단계 문구, `--version` 검증을 실제에 맞췄다. 5단계 토큰 없음 처리(D3)도 반영했다 |

### 1라운드 뒤 추가 반영 (리뷰 외, 사용자 요청)

| 항목 | 처리 | 이유 |
|---|---|---|
| 세션 타임아웃이 화면 요청에 비해 김 | 반영 | 요청 15초, 전체 30초, `waitsForConnectivity = false`(D9). D2의 근거 수치를 새 값에 맞췄다. 계획 결정 표·8단계·위험 요소 표와 README를 고쳤다 |

### 2라운드 — 스냅샷 `8c8128456fb87ab75f0460eec6dc2dae67aba14a`

| 항목 | 처리 | 이유 |
|---|---|---|
| R2-1 저장 실패 시 다음 요청이 이전 토큰을 씀 | 반영(Consider, 사용자 요청) | `unsaved`로 새 토큰을 메모리에 들고 저장소보다 먼저 읽는다. 저장이 성공하거나 만료되면 비운다(D4 보강). 기존 테스트에 다음 `currentAccessToken()` 확인을 추가했다 |
| R2-2 `summary(of:)` 테스트 없음 | 반영(Consider, 사용자 요청) | `internal static`으로 바꾸고 `LoggingMiddlewareTests`에 parameterized 테스트 1개(감싼 URLError, 감싼 AuthenticationError, 날 URLError) |
| R2-3 Retry 테스트가 에러 타입만 확인 | 반영(Consider, 사용자 요청) | 던진 `ClientError`의 `underlyingError` 코드(`.cannotConnectToHost`, `.timedOut`)까지 비교한다 |
| R2-4 `RefreshCounter`와 `CallCounter` 중복 | 반영(Consider, 사용자 요청) | 이름을 `CallCounter`로 맞췄다. 파일별 private 대역은 유지한다 |
| 번복 제안: D2에 504 포함 | 반영(사용자 결정) | 504도 이미 기다린 결과라 재시도에서 뺐다(D2 갱신). 테스트 1개. 계획 목표·7단계와 README를 고쳤다 |

### 3라운드 — 스냅샷 `bf94127ba7b47ec05c763b7364f4bfa0626e2cb4`

| 항목 | 처리 | 이유 |
|---|---|---|
| R3-1 `unsaved`를 비우는 두 분기에 테스트 없음 | 반영 | `FailingTokenStore`에 "처음 N번만 저장 실패"를 두고 테스트 2개를 추가했다(저장 성공 뒤 저장소 토큰 사용, 만료 뒤 메모리 토큰 비움·콜백 1회). 두 줄을 지우면 두 테스트가 실패하는 것을 확인했다 |
| R3-2 저장소에 직접 쓰는 경로가 생기면 `unsaved`가 가림 | 반영(Consider, 사용자 요청) | 호출자가 아직 없어 코드는 바꾸지 않았다. `unsaved` 주석, README, D4에 주의 사항을 남겼다 |
| R3-3 `SummaryCase`가 internal | 반영(Consider, 사용자 요청) | `private`로 좁혔다. 같은 형태인 `CancellationKind`, `RejectedResponse`도 함께 좁혔다. private parameterized 테스트도 모든 인자가 실행되는 것을 xcresult로 확인했다 |

### 4라운드 — 스냅샷 `0352d0c6815355c6014e54294f5b9e00b7cab00f`

| 항목 | 처리 | 이유 |
|---|---|---|
| R4-1 두 번째 갱신이 보낸 refresh token을 검증하지 않음 | 반영(Consider, 사용자 요청) | refresh 스텁이 받은 인자를 `ArgumentRecorder`에 기록하고 테스트 본문에서 `[old-refresh, new-refresh]`와 비교한다. 스텁 안에서 `#expect`를 부르지 않은 것은 실패가 테스트 흐름 밖(refresh Task)에서 기록되지 않게 하기 위해서다 |
| R4-2 만료 호출을 `try?`로 받음 | 반영(Consider, 사용자 요청) | `#expect(throws: AuthenticationError.sessionExpired)`로 바꿨다 |

### 5라운드 — 스냅샷 `821a02d5eb425e41c2d7c2bb959223d5ede38047`

지적 없음. R4-1(두 번째 갱신이 메모리의 새 refresh token을 보냄)과 R4-2(만료 호출이 `sessionExpired`를 던짐) 반영분을 확인했다.
