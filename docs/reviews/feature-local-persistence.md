# 결정 기록: feature/local-persistence

계획: [`docs/plans/2026-09-28-local-persistence.md`](../plans/2026-09-28-local-persistence.md)

리뷰어는 아래 "확정 결정"을 다시 제안하지 않는다. 뒤집어야 하면 `번복 제안` 으로 이유를 적는다.

## 확정 결정

| # | 결정 | 이유 |
| --- | --- | --- |
| D1 | `UserDefaultsKeyValueStore` 는 `UserDefaults` 대신 `suiteName` 만 보관하고 호출마다 얻는다. 잘못된 suite 이름은 `init` 에서 `preconditionFailure` 로 막는다 (R1-11) | Swift 6 SDK 에서 `UserDefaults` 가 `Sendable` 이 아니다(타입 검사로 확인). `@unchecked Sendable` 금지 규약. 잘못된 이름은 조립 시점에 드러나야 한다 |
| D2 | `SwiftDataItemCache` 는 `@ModelActor` 가 아닌 평범한 `actor` 가 첫 사용 때 `ModelContext` 를 만든다 (R1-2 확인) | main actor 에서 만들어도 작업이 메인 스레드 밖에서 도는 것을 `dispatchPrecondition` 으로, `-com.apple.CoreData.ConcurrencyDebug 1` 을 켠 채 위반이 없는 것을 테스트로 확인했다 |
| D3 | 로그인 상태가 아니게 되면(`.signedOut`, `.expired`) App 이 `CachedItemRepository.clearCache()` 로 캐시를 비운다. 앱 시작 때 첫 상태가 `.signedOut` 이어도 비운다 (R1-1) | 원격이 401 도 `.unavailable` 로 올려 캐시로 넘어간다. `ItemError.unauthorized` 를 두는 대안은 Domain·UseCase·피처까지 바뀌어 범위가 크다. 시작 때 비워도 로그인하지 않은 사용자는 목록을 받을 수 없어 잃는 것이 없다. Keychain 을 읽지 못해 첫 상태가 `.signedOut` 이면(첫 잠금 해제 전 백그라운드 실행 등) 로그인한 사용자의 캐시도 비워지지만, 그 상태에서는 원격도 인증할 수 없어 잃는 것은 캐시뿐이다(R2-3, README 에 명시) |
| D4 | 캐시 쓰기는 Data 의 `ItemCacheWriter` 가 요청 시작 순서로 줄 세운다. 이미 쓴 요청보다 먼저 시작한 요청의 쓰기, 비우기 전에 시작한 요청의 쓰기는 버린다. 쓸지 말지는 호출 시점(첫 `await` 전)에 정하고, 실제 캐시 호출은 `serialized` 로 그 순서대로 하나씩 실행한다 (R1-5, R1-1, R2-1) | 겹친 요청에서 오래된 목록이 남는 것과, 로그아웃 전에 시작한 요청이 비운 캐시를 되살리는 것을 한 규칙으로 막는다. 순서는 한 `CachedItemRepository` 인스턴스 안에서만 맞춘다(앱은 하나만 만든다). 판단만 줄 세우면 캐시 구현 안의 중단 지점이나 캐시 actor 의 우선순위 처리로 반영 순서가 바뀐다(R2-1). `AuthSession.serialized` 와 같은 방식이다 |
| D5 | 원격이 `.unavailable` 이어도 호출이 취소됐으면 캐시를 읽지 않고 그대로 던진다 (R1-4) | 결과를 버릴 호출이다 |
| D6 | 겹치는 id 는 넣기 전에 처음 것만 남긴다. 규칙은 `[ItemCacheRecord].removingDuplicateIDs()` 로 SwiftData 밖에 두고 직접 테스트한다 (R1-3) | 중복 제거를 빼면 iOS 26 시뮬레이터에서 캐시 테스트가 한 번은 통과하고 한 번은 실패했다(뮤테이션 확인). `@Attribute(.unique)` 가 겹치는 id 를 합치는 결과가 일정하지 않아 캐시 테스트만으로는 규칙을 지킬 수 없다 |
| D7 | 디스크 저장소 파일 이름은 `Persistence.store` 로 고정한다. in-memory 는 이름을 주지 않는다 (R1-6) | 기본 `default.store` 는 다른 SwiftData 사용과 충돌할 수 있다. 이름 있는 in-memory 저장소가 컨테이너끼리 공유될 가능성을 피해 테스트를 격리한다 |
| D8 | 디스크 저장소는 계속 `AppContainer.init` 에서 동기로 연다. 오래 걸리는 이동 단계를 더할 때 옮기도록 README 에 적는다 (R1-7) | 이동 단계가 비어 있는 지금은 가볍다. 비동기로 바꾸면 Repository 조립 전체가 비동기가 된다 |
| D9 | Data 의 `reportPersistenceFailure(_:)` 는 `public` 이다 | App 의 저장소 폴백이 Data 와 같은 보고 형식을 쓴다. 계획에 접근 수준이 없던 변경이라 여기 기록한다 |
| D10 | `SwiftDataItemCache` 의 `rollback()` 분기는 테스트하지 않는다 (R1-10) | in-memory 저장소로는 `save()` 실패를 일으킬 수 없다. 이유를 코드 주석에 남겼다 |
| D11 | `StubSettingsRepository` 는 정해진 값만 돌려주고 쓰기를 기록하지 않는다 | DomainTesting 에 `os`(락) 의존을 들이지 않는다. 쓰기 확인은 실제 구현과 `InMemoryKeyValueStore` 로 한다 |
| D12 | 앱 테스트 타깃은 `.testing(.diagnostics)`, `.testing(.domain)`, `.testing(.core("Persistence"))` 에 의존해 기존 대역을 쓴다 (R1-8, R2-4) | 같은 일을 하는 대역을 앱 테스트에 새로 만들지 않는다 |
| D13 | 쓰기 기준은 `max(성공한 번호, 진행 중인 번호, 비우기 기준)` 으로 매번 계산한다. 실패한 쓰기는 끝나는 즉시 진행 중 목록에서 빠지고 성공 번호는 바뀌지 않는다. 비우기 기준(`clearedThrough`)은 따로 두고 되돌리지 않는다. 실패한 쓰기가 진행되는 동안 도착해 이미 버려진 요청은 되살리지 않는다 (R2-2, R3-1에서 방식 변경) | 실패한 최신 쓰기 때문에 뒤이어 끝나는 요청의 정상 결과까지 버려 더 오래된 목록이 남는 것을 막는다. "시작할 때의 기준"으로 되돌리면 쓰기가 연달아 실패할 때 한 번도 쓰이지 않은 번호가 기준으로 남는다(R3-1). 기준을 하나로 두면 비우기의 무효화까지 풀린다. 버려진 요청을 기다렸다 되살리는 것은 드문 경우에 비해 복잡해 받아들인다 |
| D14 | `ItemCacheWriter.waitUntilOperationsQueued(_:)` 를 같은 파일의 internal 확장(테스트 동기화 지점)으로 둔다 (R2-1) | 앞선 쓰기를 붙잡은 채 비우기가 줄에 들어갔는지 sleep 없이 확인할 방법이 없다. Auth 의 D10 과 같은 방식이다 |
| D15 | 저장소는 `groupContainer: .none`, `cloudKitDatabase: .none` 을 명시한다 (R2-6) | `.automatic` 이면 엔타이틀먼트를 더하는 순간 위치가 그룹 컨테이너로 조용히 바뀌어(D7 위반) 캐시를 잃거나, `@Attribute(.unique)` 때문에 CloudKit 저장소 열기가 실패한다 |
| D16 | `AppContainer.startClearingItemCache(of:whenSignedOutIn:)` 는 internal 이고 `@discardableResult` 로 Task 를 돌려준다 (R2-4) | 앱은 Task 를 버리고, 테스트는 끝나는 상태 스트림을 넘겨 Task 를 기다려 실제 Repository 까지의 연결을 확인한다 |
| D17 | `ItemCacheWriter` 의 순서 보장은 쓰기·비우기에만 적용한다. 캐시 읽기는 줄을 거치지 않는다. `serialized` 의 캐시 호출에는 부른 쪽의 취소가 전달되지 않는다 (R3-3, R3-4) | 비우기와 읽기의 순서는 처음부터 맞추지 않았다(로그아웃과 겹친 한 번의 읽기만 영향). 지금 `SwiftDataItemCache` 는 취소를 보지 않아 동작 차이가 없다. 둘 다 코드 주석에 적었다 |
| D18 | 회귀가 생기면 붙잡힌 쓰기 뒤에서 멈추는 테스트에는 `.timeLimit(.minutes(1))` 을 건다. 대역은 첫 쓰기만 붙잡는다 (R4-1) | 멈춤은 실패가 아니라 CI 정지로 드러난다. Swift Testing 의 시간 제한 최소 단위가 분이라 1분으로 둔다 |

## 라운드 이력

### 1라운드 — 스냅샷 `c730d476f95c6a283b27445c40c005028e9d0a2e`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R1-1 (Should fix) 로그아웃 뒤 이전 계정 캐시 | 반영 | `ItemCache.removeAll()`, `CachedItemRepository.clearCache()`, `AppContainer.clearItemCacheWhenSignedOut(statuses:clear:)`(D3). 비우기 전에 시작한 요청이 캐시를 되살리지 않게 D4 로 막음. 계획 결정 사항에 추가 |
| R1-2 ConcurrencyDebug 확인 | 반영 | 플래그가 테스트 프로세스에 전달된 것(값 1)을 확인하고 `SwiftDataItemCacheTests` 가 위반 없이 통과(D2) |
| R1-3 중복 id | 반영 | 처음 것만 남김(D6). `removingDuplicateIDs_withDuplicates_keepsFirstOccurrencesInOrder` |
| R1-4 취소 처리 | 반영 | D5. `fetchItems_cancelledWhileRemoteUnavailable_throwsUnavailableWithoutCache` |
| R1-5 겹친 요청의 쓰기 순서 | 반영 | D4. `fetchItems_earlierRequestFinishesLast_keepsLaterResultInCache`, `clearCache_whileRequestInFlight_doesNotWriteStaleResult` |
| R1-6 저장소 파일 이름 | 반영 | D7. 계획 롤백 문구와 README 수정 |
| R1-7 동기 저장소 열기 | 반영(문서) | D8. README "스키마 버전 올리기" 에 주의 추가 |
| R1-8 앱 테스트의 중복 스파이 | 반영 | D12 |
| R1-9 Privacy manifest 검증 | 반영 | `manifest_userDefaults_declaresAppOnlyReason` |
| R1-10 `rollback()` 테스트 | 반영(주석) | D10 |
| R1-11 `_ = defaults` 의도 | 반영 | D1. `init` 에서 명시적으로 검사 |
| R1-12 단계별 커밋 | 반영 | 계획 1~6단계별로 커밋하고, 리뷰 반영분은 해당 단계 커밋에 넣었다 |

R1-1, R1-4, R1-5, R1-3 의 수정을 하나씩 되돌렸을 때 새 테스트가 실패하는 것을 확인했다(뮤테이션 확인). R1-3 은 캐시 테스트의 실패 여부가 실행마다 달라(D6) 규칙을 함수로 빼 직접 테스트했다. 함수 테스트는 되돌리면 늘 실패한다.

### 2라운드 — 스냅샷 `89599d0f1e62cc012b68761021cae7486ba0a69d`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R2-1 (Should fix) 판단과 캐시 호출 사이 재진입 | 반영 | 캐시 호출을 `serialized` 로 줄 세움(D4 보강). `removeAll_whileEarlierWriteIsInsideCache_leavesCacheEmpty`. 동기화 지점 D14 |
| R2-2 실패한 쓰기가 기준을 올려 둠 | 반영 | 실패 시 되돌림, 비우기 기준 분리(D13). `replaceAll_afterLaterWriteFailed_writesEarlierResult`, `replaceAll_afterWriteFailedDuringClear_doesNotWriteRequestStartedBeforeClear` |
| R2-3 Keychain 읽기 실패 시 캐시 삭제 | 반영(문서) | D3 이유와 README "주의" 에 추가 |
| R2-4 조립 연결 테스트 | 반영 | D16. `startClearingItemCache_signedOut_clearsRepositoryCache` |
| R2-5 쓰지 않는 카운터 | 반영 | 취소 테스트가 `loadCount == 0` 을 확인한다. `removeAllCount` 는 R2-4 테스트가 쓴다 |
| R2-6 앱 그룹·CloudKit 자동 설정 | 반영 | D15 |

R2-1(직렬화 제거), R2-2(되돌림 제거), D13 의 비우기 기준 분리를 하나씩 되돌렸을 때 새 테스트가 실패하는 것을 확인했다(뮤테이션 확인).

### 3라운드 — 스냅샷 `12aaf811ee41fd41e8a4fcccaf2bbc5cb0a66d4b`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R3-1 (Should fix) 연속 실패 시 되돌린 기준 | 반영 | 성공 번호와 진행 중 번호로 기준을 계산(D13 방식 변경, 목적은 같음). `replaceAll_afterTwoLaterWritesFailed_writesEarliestResult` |
| R3-2 (Should fix) 실패 뒤 더 늦은 쓰기 성공 분기 테스트 | 반영 | `replaceAll_afterFailedWriteFollowedBySuccessfulLaterWrite_keepsLaterResult` |
| R3-3 취소가 전달되지 않음 | 반영(주석) | D17. `serialized` 주석 |
| R3-4 읽기는 줄을 거치지 않음 | 반영(주석) | D17. `ItemCacheWriter` 문서 주석에 적용 범위를 쓰기·비우기로 한정 |

R3-1(실패한 쓰기를 진행 중 목록에 남김), R3-2(성공 번호 기록 제거)를 하나씩 되돌렸을 때 새 테스트가 실패하는 것을 확인했다(뮤테이션 확인).

### 4라운드 — 스냅샷 `3fc8ac57439e0ad8e479d98ca015788e63e30c23`

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R4-1 (Should fix) 진행 중 쓰기 조건 테스트 누락 | 반영 | `replaceAll_whileLaterWriteInFlight_dropsEarlierResult`(D18). 조건을 빼면 60초 제한에서 실패함을 확인했다(뮤테이션 확인) |
| R4-2 테스트 이름·주석이 이전 방식을 설명 | 반영 | "기준을 되돌려도" → "실패해도", 주석을 "실패한 쓰기가 기준에서 빠진 뒤" 로 |
| R4-3 타입 문서 주석과 D13 불일치 | 반영 | "쓰기에 성공했거나 쓰는 중인 요청보다" 로 맞추고 비우기 기준이 따로임을 적었다 |

### 5라운드 — 스냅샷 `bec96faa31a294cbd54df3b75bc0790b590944c8`

Blocker·Should fix 없음.

| 항목 | 처리 | 이유 |
| --- | --- | --- |
| R5-1 확정 결정 표 순서 | 반영 | D1~D18 순서로 정렬 |
