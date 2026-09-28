# 결정 기록: feature/local-persistence

계획: [`docs/plans/2026-09-28-local-persistence.md`](../plans/2026-09-28-local-persistence.md)

리뷰어는 아래 "확정 결정"을 다시 제안하지 않는다. 뒤집어야 하면 `번복 제안` 으로 이유를 적는다.

## 확정 결정

| # | 결정 | 이유 |
| --- | --- | --- |
| D1 | `UserDefaultsKeyValueStore` 는 `UserDefaults` 대신 `suiteName` 만 보관하고 호출마다 얻는다. 잘못된 suite 이름은 `init` 에서 `preconditionFailure` 로 막는다 (R1-11) | Swift 6 SDK 에서 `UserDefaults` 가 `Sendable` 이 아니다(타입 검사로 확인). `@unchecked Sendable` 금지 규약. 잘못된 이름은 조립 시점에 드러나야 한다 |
| D2 | `SwiftDataItemCache` 는 `@ModelActor` 가 아닌 평범한 `actor` 가 첫 사용 때 `ModelContext` 를 만든다 (R1-2 확인) | main actor 에서 만들어도 작업이 메인 스레드 밖에서 도는 것을 `dispatchPrecondition` 으로, `-com.apple.CoreData.ConcurrencyDebug 1` 을 켠 채 위반이 없는 것을 테스트로 확인했다 |
| D3 | 로그인 상태가 아니게 되면(`.signedOut`, `.expired`) App 이 `CachedItemRepository.clearCache()` 로 캐시를 비운다. 앱 시작 때 첫 상태가 `.signedOut` 이어도 비운다 (R1-1) | 원격이 401 도 `.unavailable` 로 올려 캐시로 넘어간다. `ItemError.unauthorized` 를 두는 대안은 Domain·UseCase·피처까지 바뀌어 범위가 크다. 시작 때 비워도 로그인하지 않은 사용자는 목록을 받을 수 없어 잃는 것이 없다 |
| D4 | 캐시 쓰기는 Data 의 `ItemCacheWriter` 가 요청 시작 순서로 줄 세운다. 이미 반영한 요청보다 먼저 시작한 요청의 쓰기, 비우기 전에 시작한 요청의 쓰기는 버린다 (R1-5, R1-1) | 겹친 요청에서 오래된 목록이 남는 것과, 로그아웃 전에 시작한 요청이 비운 캐시를 되살리는 것을 한 규칙으로 막는다. 순서는 한 `CachedItemRepository` 인스턴스 안에서만 맞춘다(앱은 하나만 만든다) |
| D5 | 원격이 `.unavailable` 이어도 호출이 취소됐으면 캐시를 읽지 않고 그대로 던진다 (R1-4) | 결과를 버릴 호출이다 |
| D6 | 겹치는 id 는 넣기 전에 처음 것만 남긴다. 규칙은 `[ItemCacheRecord].removingDuplicateIDs()` 로 SwiftData 밖에 두고 직접 테스트한다 (R1-3) | 중복 제거를 빼면 iOS 26 시뮬레이터에서 캐시 테스트가 한 번은 통과하고 한 번은 실패했다(뮤테이션 확인). `@Attribute(.unique)` 가 겹치는 id 를 합치는 결과가 일정하지 않아 캐시 테스트만으로는 규칙을 지킬 수 없다 |
| D7 | 디스크 저장소 파일 이름은 `Persistence.store` 로 고정한다. in-memory 는 이름을 주지 않는다 (R1-6) | 기본 `default.store` 는 다른 SwiftData 사용과 충돌할 수 있다. 이름 있는 in-memory 저장소가 컨테이너끼리 공유될 가능성을 피해 테스트를 격리한다 |
| D8 | 디스크 저장소는 계속 `AppContainer.init` 에서 동기로 연다. 오래 걸리는 이동 단계를 더할 때 옮기도록 README 에 적는다 (R1-7) | 이동 단계가 비어 있는 지금은 가볍다. 비동기로 바꾸면 Repository 조립 전체가 비동기가 된다 |
| D9 | Data 의 `reportPersistenceFailure(_:)` 는 `public` 이다 | App 의 저장소 폴백이 Data 와 같은 보고 형식을 쓴다. 계획에 접근 수준이 없던 변경이라 여기 기록한다 |
| D10 | `SwiftDataItemCache` 의 `rollback()` 분기는 테스트하지 않는다 (R1-10) | in-memory 저장소로는 `save()` 실패를 일으킬 수 없다. 이유를 코드 주석에 남겼다 |
| D11 | `StubSettingsRepository` 는 정해진 값만 돌려주고 쓰기를 기록하지 않는다 | DomainTesting 에 `os`(락) 의존을 들이지 않는다. 쓰기 확인은 실제 구현과 `InMemoryKeyValueStore` 로 한다 |
| D12 | 앱 테스트 타깃은 `.testing(.diagnostics)` 에 의존해 `SpyDiagnosticReporter` 를 쓴다 (R1-8) | 같은 일을 하는 대역을 앱 테스트에 새로 만들지 않는다 |

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
