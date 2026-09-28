# 결정 기록: feature/auth-module

계획: [`docs/plans/2026-09-28-auth-module.md`](../plans/2026-09-28-auth-module.md)

리뷰어는 아래 "확정 결정"을 다시 제안하지 않는다. 뒤집어야 하면 `번복 제안` 으로 이유를 적는다.

## 확정 결정

| # | 결정 | 이유 |
| --- | --- | --- |
| D1 | `AuthSession` 의 저장소 읽기·저장·삭제는 요청한 순서대로 하나씩 실행한다(`serialized`) | 세대 확인만으로는 갱신 결과 저장이 진행 중일 때 끼어든 로그아웃 삭제보다 늦게 끝나 토큰이 되살아나는 경쟁을 막지 못한다 |
| D2 | 갱신의 세대는 갱신할 토큰을 **읽기 전에** 잡고, 읽은 뒤·refresh 뒤·저장 뒤마다 확인한다 (R1-1) | 읽는 동안 로그인·로그아웃이 끼면 읽은 토큰이 이전 세션의 것이다. 서버 로그아웃이 없어 이전 refresh token 이 유효하므로 갱신이 성공해 되살아난다 |
| D3 | `inFlight` 는 기다린 Task 와 같을 때만 비운다 | 이전 세대 호출의 `defer` 가 새 세대 갱신을 떼어 내면 같은 refresh token 으로 갱신이 중복된다(교체 방식 서버에서 세션 만료) |
| D4 | 이전 세대의 갱신이 거절돼도 `expireSession()` 을 부르지 않는다 | 거절된 것은 이전 세션이다. 새 로그인 토큰을 지우고 `.expired` 를 보내면 안 된다 |
| D5 | 로그아웃·만료는 삭제를 기다리기 **전에** 상태를 알린다. 로그인은 저장 성공 뒤에 알린다 | 기다리는 동안 다른 전환이 먼저 알리면 알림 순서가 뒤집힌다 |
| D6 | 로그인 저장 중 다른 전환이 먼저 끝나면 `signIn` 은 `CancellationError` 를 던진다(Repository 는 `.unavailable`) | 조용히 성공하면 호출부는 로그인했다고 보지만 상태는 `.signedOut` 이다 |
| D7 | 로그인은 저장 **전에** 세대를 올린다. 저장 실패 시 진행 중 갱신 결과가 버려지는 것은 받아들인다 (R1-6) | 저장 뒤에 올리면 앞선 갱신 저장(D1 로 로그인 저장보다 먼저 실행)이 끝난 뒤 세대가 같아 이전 세션 토큰이 로그인 토큰을 덮어쓸 수 있다. 손실은 "로그인된 상태에서 재로그인 + Keychain 저장 실패" 라는 드문 경우뿐이다 |
| D8 | 로그아웃·만료가 **시작될 때** 삭제 결과와 관계없이 저장소 읽기를 막는다(`storeDiscarded`, 로그인 성공 시에만 해제). 재시작 뒤에는 남은 토큰을 읽는다 (R1-2, R2-1 에서 범위 확대) | 삭제 실패 뒤에만 켜면 삭제가 진행되는 동안 이미 줄을 선 읽기와, 동시 로그인 저장까지 실패한 경우를 놓친다. 삭제가 성공하면 저장소가 비어 있어 동작은 같다. 재시작 뒤까지 막으려면 별도 영속 표식이 필요하고 Keychain 삭제 실패는 드물어 한계로 둔다(Auth README 에 명시) |
| D9 | 미들웨어는 `AccessTokenProviding`, Repository 는 `SessionManaging` 프로토콜에 의존한다. 구현은 `AuthSession` 하나. 상태 타입은 최상위 `AuthSessionState`(`AuthSession.State` 는 typealias) (R1-8, R2-3) | `.claude/rules/swift.md` "프로토콜에 의존". 프로토콜 대역이 구체 타입 이름에 묶이지 않게 한다 |
| D10 | 테스트 동기화 지점(`isRefreshInFlight`, `waitUntilGeneration(atLeast:)`, `waitUntilNoSubscribers()`)을 `AuthSession.swift` 안의 internal 확장으로 둔다 (R2-2) | actor 안의 전환 시점을 sleep 없이 맞출 방법이 없다. internal 이라 `@testable import` 만 쓴다. private 상태를 읽어야 해서 별도 파일(`AuthSession+TestSupport.swift`)로 빼지 않는다 |
| D11 | 생성 클라이언트 에러 보고는 Data 의 `DiagnosticReporting.reportNetworkFailure(_:)` 하나로 한다 (R1-7) | `RemoteItemRepository`·`RemoteAuthRepository` 의 같은 코드 중복 제거. 계획 변경 목록에 없던 추출이라 여기 기록한다 |
| D12 | 로그인 저장 실패·로그아웃 삭제 실패는 `AuthSession` 이 로그로 남기고, 진단 보고(Crashlytics)는 하지 않는다 | Keychain 실패는 네트워크 실패가 아니라 `NetworkFailure` 보고 규칙 밖이다 |
| D13 | `states()` 는 `async` 다 | 첫 값(현재 상태)을 정하려면 저장소를 읽어야 한다 |
| D14 | 1단계에서 스캐폴드 자리표시 테스트를 2단계까지 남겼다 | 빈 테스트 타깃은 번들 로드 실패로 테스트가 깨진다 |
| D15 | `FailingTokenStore` 는 `AuthTesting` 에 둔다(실패는 `FailingTokenStore.Failure`) (R2-4) | Auth·Data 테스트가 같은 대역을 쓴다. 모듈이 공개하는 테스트 더블 규칙 |

## 라운드 이력

### 1라운드 — 스냅샷 `e9946349f5157c1ccd75069687983a94f6746b5e`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R1-1 (Blocker) 읽는 중 전환 | 반영 | 세대를 `load` 전에 잡고 읽은 뒤 확인(D2). `refresh_signOutDuringLoad_doesNotRestoreTokens`, `refresh_signInDuringLoad_keepsNewTokens` 추가 |
| R1-2 로그아웃 삭제 실패 뒤 읽기 | 반영 | `storeDiscarded`(D8). 만료 삭제 실패에도 적용. 재시작 한계는 결정으로 기록 |
| R1-3 이전 세대 거절 분기 테스트 | 반영 | `refresh_rejectedAfterSignIn_keepsNewSession` |
| R1-4 `inFlight` 비교 분기 테스트 | 반영 | `refresh_staleWaiterFinishes_keepsNewRefreshInFlight`. `RefreshGate` 가 여러 호출을 붙잡도록 확장 |
| R1-5 Repository 실패 매핑 테스트 | 반영 | `signIn_storeFails_throwsUnavailableWithoutReport`, `signOut_storeFails_throwsUnavailableAndEmitsSignedOut` |
| R1-6 로그인 저장 전 세대 증가 | 반영(기록) | 동작 유지, 이유를 D7 로 기록 |
| R1-7 보고 헬퍼 추출 추적 | 반영(기록) | D11 로 기록 |
| R1-8 구체 actor 의존 | 반영 | `AccessTokenProviding`, `SessionManaging` 도입(D9) |
| R1-9 구독 정리 테스트 | 반영 | `states_subscriberCancelled_removesSubscription`(Auth), `sessionStatuses_cancelled_releasesSessionSubscription`(Data) |

R1-1~R1-4 의 수정 코드를 하나씩 되돌렸을 때 새 테스트가 실패하는 것을 확인했다(뮤테이션 확인).

### 2라운드 — 스냅샷 `263020000f31c4299c67f2d44582c87023d257a2`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R2-1 삭제 중·동시 저장 실패 시 읽기 | 반영 | 로그아웃·만료 시작 시 `storeDiscarded` 를 켜고 `discardStoreIfCurrent` 삭제(D8 범위 확대, 번복 아님). `signOut_readDuringFailingClear_doesNotUseStaleTokens`, `signIn_saveFailsDuringFailingClear_doesNotUseStaleTokens` 추가. 이전 동작으로 되돌리면 둘 다 실패함을 확인 |
| R2-2 없는 파일을 가리키는 주석 | 반영 | 주석 수정. 확장은 private 상태 접근 때문에 같은 파일에 둔다(D10) |
| R2-3 프로토콜이 중첩 타입 반환 | 반영 | 최상위 `AuthSessionState` + `AuthSession.State` typealias(D9) |
| R2-4 테스트 대역 중복 | 반영 | `FailingTokenStore` 를 AuthTesting 으로 옮기고 Data 의 `FailingStore` 삭제(D15) |

### 3라운드 — 스냅샷 `4cc41ebb57670abbca9fb8ad2670651526ee9ee0`

Blocker·Should fix 없음. D8 범위 확대(R2-1)는 전환 조합별로 문제 경로가 없음을 리뷰어가 확인했다.

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R3-1 `waitUntilGeneration` 뒤 주석이 저장 순서를 보장하는 것처럼 씀 | 반영 | "세대를 올린 뒤다. 순서와 관계없이 결과는 같다" 로 수정. 같은 표현이던 R1-1 테스트 두 곳(읽는 중 로그아웃·로그인)도 함께 고침. 세 테스트 모두 어느 순서든 결과가 같아 동기화 지점은 추가하지 않음 |
| R3-2 테스트 더블 파일 머리 주석 | 반영 | "이 테스트 타깃(AuthTests)이 쓰는 테스트 더블" 로 수정 |
| R3-3 Data 매니페스트 주석 | 반영 | `InMemoryTokenStore, FailingTokenStore` 로 수정 |

