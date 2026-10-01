# 결정 기록: fix/review-template-r1

계획: 없음. `main` 저장소 전체 리뷰(템플릿, CD 제외) 1라운드 결과를 입력으로 삼았다.

리뷰어는 아래 "확정 결정"을 다시 제안하지 않는다. 뒤집어야 하면 `번복 제안` 으로 이유를 적는다.

## 확정 결정

| # | 결정 | 이유 |
| --- | --- | --- |
| T-D1 | `HomeViewModel.load()` 는 호출마다 번호를 매기고, 마지막으로 시작한 호출만 상태를 쓴다. `HomeView` 의 `.task` 는 `.idle` 뿐 아니라 `.loading` 일 때도 부른다 (R1-1) | 토큰 갱신을 기다리는 요청은 취소돼도 바로 돌아오지 않는다. 그사이 화면이 다시 나타나면 `.loading` 이라 부르지 않았고, 늦게 끝난 이전 호출이 `.idle` 을 써서 스피너가 멈췄다. 이전 결정 R-D1(취소되면 `.idle`)은 그대로 둔다. 마지막 호출일 때만 적용된다. 성공·실패 두 경로의 번호 확인을 각각 짝 테스트로 고정한다 (R2-1) |
| T-D2 | `PersistenceError` 보고의 `errorType` 은 `"PersistenceError.<case 이름>"` 이다 (R1-2) | fingerprint 가 case 마다 달라야 5분 억제 창에서 한 원인이 다른 원인을 가리지 않는다. `NetworkFailure` 의 `타입.case` 규칙과 같다. local-persistence 계획의 보고 형식 줄도 고쳤다 |
| T-D3 | `AccessTokenProviding.currentAccessToken()` 은 `SessionToken(value:, generation)` 을 돌려주고, 401 을 받은 요청은 그 값을 `refreshedAccessToken(rejected:)` 에 그대로 넘긴다. 세대가 지금과 다르면 진행 중인 갱신에 합류하지 않고 `sessionExpired` 를 던진다 (R1-3) | 요청을 보낸 뒤 401 이 오기 전에 세션이 바뀌면, 이전 세션의 요청이 새 계정의 토큰으로 다시 나갔다. auth D2 는 "읽는 동안"만 다뤘다. 세대는 `internal` 이라 `AuthSession` 밖에서 만들 수 없다. Auth 테스트는 `@testable` 의 `rejecting(_:)` 으로 현재 세대 값을 만든다 |
| T-D8 | `currentAccessToken()` 은 세대를 저장소를 읽기 **전에** 잡는다. 읽는 중에 로그인한 경우를 게이트 테스트로 고정한다 (R2-2) | 읽기가 `signIn` 의 저장보다 먼저 줄을 서면 이전 계정 토큰을 받는다. 세대를 읽은 뒤에 잡으면 그 토큰에 새 세대가 붙어 T-D3 이 막으려던 재전송이 되살아난다 |
| T-D9 | 홈의 진입·재시도는 화면 수명에 묶인 `.task(id: viewModel.retryRequest)` 하나로 부른다. 재시도 카운터, 처리한 값, 부를지 판단(`loadOnAppear()`)은 모두 뷰모델이 갖는다. 재시도 버튼은 `retry()` 만 부른다 (R2-3, R3-1) | 화면을 벗어나면 재시도도 취소되어, 돌아왔을 때 `.loading` 재호출과 겹치지 않는다. 재진입은 재시도가 아니므로 `.failed` 화면은 버튼을 누를 때까지 그대로 둔다. 판단을 뷰에 두면 테스트할 수 없어서 뷰모델로 옮겼다. 리뷰 제안(`loadOnAppear(isRetry:)`)과 달리 카운터 비교 순서까지 옮겨, 순서가 바뀌는 회귀도 테스트가 잡는다. `.idle`·`.loading`·재시도·재진입 분기마다 테스트가 있다 (R4-1) |
| T-D10 | 화면 재진입처럼 "부르지 않으면 회귀"인 경우를 테스트할 때는 게이트 대역이 그 호출을 막지 않게 한다(`GatedFetchItemsUseCase(laterResult:)`). 테스트는 호출을 끝까지 `await` 한 뒤 상태로 단언한다 (R5-1) | 그 호출까지 게이트에 걸면 회귀했을 때 `started.next()` 에서 멈춘다. 그러면 `.timeLimit` 의 최소 단위인 1분이 지나서야 원인 없는 시간 초과로 실패하고, continuation 누수 경고도 남는다. 호출 횟수를 세는 방식은 "아직 시작 안 함"과 "부르지 않음"을 가를 수 없어 경쟁이 남는다 |
| T-D4 | Crashlytics 이슈 domain 접두사는 출처와 상관없이 `diagnostic` 이다. 출처는 `errorType` 이 드러낸다 (R1-4) | 저장소 실패가 `network.` 이슈로 분류됐다. 출처별로 접두사를 고르면 규칙이 하나 더 생긴다. 아직 배포 전 템플릿이라 기존 이슈가 갈라지는 비용이 없다. Diagnostics README 와 diagnostics 계획 두 곳의 domain 형식도 고쳤다 |
| T-D5 | 푸시 이미지 첨부 실패는 에러 타입과 코드만 `Logger.error`(category `PushAttachment`)로 남긴다. URL 은 남기지 않는다 (R1-5) | 원인(2xx 가 아닌 응답, 타임아웃, 첨부 생성 실패)을 가릴 수 있어야 한다. URL 에는 사용자별 값이 담길 수 있다. 주석에는 원인별로 실제 로그에 찍히는 값을 적는다. `type(of:)` 는 브리징된 이름(`NSURLError`, `NSError`)을 찍으므로 `URLError`·`CocoaError` 로 쓰지 않는다. 파일 이동과 첨부 생성 실패는 둘 다 `NSError` 라 코드로만 구분한다. domain 까지 찍는 변경은 하지 않았다 (R2-4, R3-2, R4-2) |
| T-D6 | 항목 캐시는 첫 상태가 아닌 `.signedIn` 에서도 비운다. 첫 `.signedIn`(저장된 세션 발견)은 비우지 않는다 (R1-6) | 로그아웃 없이 다른 계정으로 로그인할 수 있다. 로그아웃 뒤에 끝난 이전 계정의 요청이 캐시를 채웠을 수도 있다. 같은 계정으로 다시 로그인했을 때 캐시를 한 번 더 받는 비용은 작다 |
| T-D7 | `makeHomeView` 가 `body` 평가마다 뷰모델을 새로 만드는 구조는 그대로 두고, 뷰모델 `init` 에 부수효과를 두지 않는다는 주석만 단다 (R1-7) | `@State` 가 첫 인스턴스만 쓰므로 동작은 맞다. 구조를 바꾸면 컨테이너가 화면 수명을 알아야 한다 |

## 라운드 이력

### 1라운드: 스냅샷 `5c4997f7c6e2c50f9292f7eea6414089ee2e7bbf`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R1-1 (Should fix) 늦게 끝난 취소 로드가 `.idle` 을 써서 스피너가 멈춤 | 반영 | T-D1. `load_cancelledLoadFinishesLate_keepsLatestResult` 추가. 번호 확인을 빼면 실패하는 것을 확인 |
| R1-2 (Should fix) `PersistenceError` 의 모든 case 가 같은 fingerprint | 반영 | T-D2. `PersistenceFailureReportTests` 추가, `LocalSettingsRepositoryTests` 기대값 수정 |
| R1-3 (Should fix) 요청 뒤 재로그인하면 이전 요청이 새 토큰으로 다시 나감 | 반영 | T-D3. AuthSession 테스트 2개, AuthMiddleware 테스트 1개 추가. 세대 확인을 빼면 셋 다 실패하는 것을 확인. 기존 Auth 테스트 호출부는 `rejecting(_:)` 으로 옮김 |
| R1-4 (Consider) 저장소 실패가 `network` domain 으로 분류됨 | 반영 | 사용자가 전부 반영을 요청했다. T-D4. `nsError_persistenceFailure_isNotNetworkDomain` 추가 |
| R1-5 (Consider) 첨부 실패 로그 없음 | 반영 | 사용자가 전부 반영을 요청했다. T-D5. 익스텐션 단위 테스트 타깃이 없어 테스트는 추가하지 않았다 |
| R1-6 (Consider) `.signedIn` → `.signedIn` 에서 캐시를 비우지 않음 | 반영 | 사용자가 전부 반영을 요청했다. T-D6. 재로그인 테스트 2개 추가. 분기를 되돌리면 실패하는 것을 확인 |
| R1-7 (Consider) `body` 평가마다 뷰모델 생성 | 반영(주석만) | 사용자가 전부 반영을 요청했다. 리뷰 제안대로 경고 주석만 달았다. T-D7 |

### 2라운드: 스냅샷 `8bea6963ce596458e8a0d54cfd335c6d74abac9d`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R2-1 (Should fix) 성공 경로의 번호 확인에 테스트가 없음 | 반영 | T-D1 갱신. `load_cancelledLoadSucceedsLate_keepsLatestFailure` 추가. 성공 쪽 guard 를 빼면 실패하는 것을 확인 |
| R2-2 (Should fix) 세대를 읽기 전에 잡는 순서를 고정하는 테스트가 없음 | 반영 | T-D8. `refresh_signedInDuringRead_throwsSessionExpiredWithoutNewToken` 추가. 세대를 읽기 뒤에 잡게 바꾸면 실패하는 것을 확인 |
| R2-3 (Consider) 재시도 Task 가 화면 수명에 묶이지 않아 요청이 겹침 | 반영 | 사용자가 전부 반영을 요청했다. T-D9. 뷰 단위 테스트 타깃이 없어 테스트는 추가하지 않았다 |
| R2-4 (Consider) 첨부 실패 주석의 원인 예시가 로그 값과 맞지 않음 | 반영 | 사용자가 전부 반영을 요청했다. T-D5 갱신 |
| R2-5 (Consider) Crashlytics 접두사 테스트 이름이 의도와 다름 | 반영 | 사용자가 전부 반영을 요청했다. `nsError_persistenceFailure_usesSamePrefixAsNetwork` 로 이름을 바꿨다. 출처별 접두사 분기를 다시 넣는 회귀를 막는다(T-D4) |

### 3라운드: 스냅샷 `87d7890f77798c66d40e83d3ae24c1de20b6b707`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R3-1 (Should fix) 재시도 판단에 테스트가 없음 | 반영 | T-D9 갱신. 판단을 `HomeViewModel.loadOnAppear()`·`retry()` 로 옮기고 테스트 3개를 추가했다. 테스트는 재진입이면 실패를 유지하는 것, 재시도면 다시 불러오는 것, 재시도 한 번은 한 번만 처리하는 것을 본다. `isRetry \|\|` 를 빼거나 비교와 갱신의 순서를 바꾸면 각각 실패하는 것을 확인 |
| R3-2 (Consider) 원인 주석에 파일 이동 실패가 빠짐 | 반영 | 사용자가 전부 반영을 요청했다. `CocoaError` 코드를 주석에 더했다. T-D5 갱신 |

### 4라운드: 스냅샷 `d8bf1f11cd28b51cffbd713a9436a3eb79ef45f6`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R4-1 (Should fix) `loadOnAppear()` 의 `.loading` 분기에 테스트가 없음 | 반영 | `loadOnAppear_loadingAfterCancel_loadsAgain` 추가. `\|\| state == .loading` 을 빼면 실패하는 것을 확인. T-D9 갱신 |
| R4-2 (Consider) 주석의 타입 이름이 실제 로그 값과 다름 | 반영(주석만) | 사용자가 전부 반영을 요청했다. macOS 에서 직접 돌려 `NSError(4)`·`NSURLError(-1004)` 가 찍히는 것을 확인하고 주석을 고쳤다. T-D5 의 형식(타입과 코드)은 바꾸지 않았다 |
| R4-3 (Consider) 테스트 대역이 `preconditionFailure` 로 프로세스를 죽임 | 반영 | 사용자가 전부 반영을 요청했다. `Issue.record` 후 `.unavailable` 을 던진다. `StubAPI` 와 같은 방식이다 |

### 5라운드: 스냅샷 `2348b26417f5fb7a193f8afabd9081b6bd0d9793`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R5-1 (Consider) `.loading` 분기 회귀가 1분 시간 초과로만 드러남 | 반영(제안과 다른 방식) | 사용자가 반영을 요청했다. T-D10. 리뷰가 제안한 호출 횟수 단언은 경쟁이 남아, 두 번째 호출을 게이트에서 빼는 방식으로 바꿨다. 분기를 빼면 0.011초 만에 `state == .loaded` 단언으로 실패하고, 시간 초과나 누수 경고가 없는 것을 확인 |
