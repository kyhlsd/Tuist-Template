# Persistence

기기 안 저장소를 맡는다. 키-값 설정(UserDefaults)과 구조화 데이터(SwiftData)를 이 모듈에 가둔다.
Foundation, SwiftData 외에는 import 하지 않는다(Testing 타깃은 락 때문에 `os` 도 쓴다).
Domain 을 모르므로 `Item` 같은 엔티티와의 변환은 Data 가 맡는다.

의존 방향: Data → Persistence. App 이 조립한다. Feature 는 이 모듈을 모르고 Domain 의 `ItemRepository`,
`SettingsRepository` 만 쓴다. 비밀값(토큰 등)은 여기 두지 않고 Auth 의 `KeychainTokenStore` 에 둔다.

## 구성

| 위치 | 내용 |
|---|---|
| `Sources/PersistenceError.swift` | `encodingFailed`, `decodingFailed`, `storeUnavailable`, `operationFailed`. 원인 에러는 담지 않는다 |
| `Sources/KeyValueStore.swift` | 원시 `Data` 저장 프로토콜(동기) |
| `Sources/SettingKey.swift` | 값 타입과 기본값을 가진 키 |
| `Sources/KeyValueStore+Codable.swift` | `value(for:)`, `setValue(_:for:)`. JSON 인코딩과 기본값 처리 |
| `Sources/UserDefaultsKeyValueStore.swift` | UserDefaults 어댑터. 모든 키 앞에 `persistence.` 를 붙인다 |
| `Sources/LocalDatabase.swift` | `ModelContainer` 래퍼. `.onDisk`(`Persistence.store`) / `.inMemory`. 여러 캐시가 공유한다 |
| `Sources/PersistenceSchemaV1*.swift` | V1 버전 스키마와 `ItemEntity` |
| `Sources/PersistenceMigrationPlan.swift` | 스키마 목록과 이동 단계(지금은 비어 있다) |
| `Sources/ItemCache.swift`, `ItemCacheRecord.swift` | 캐시 프로토콜(읽기·교체·비우기)과 actor 경계를 넘는 `Sendable` 레코드 |
| `Sources/ItemCacheRecord+UniqueID.swift` | 겹치는 id 정리(처음 것만 남김) |
| `Sources/SwiftDataItemCache.swift` | SwiftData 구현(`actor`) |
| `Testing/Sources/` | `InMemoryKeyValueStore`, `InMemoryItemCache` (`loadCount`, `replaceAllCount`, `removeAllCount` 기록), `FailingItemCache` |

## 동작 규칙

### 키-값 설정

- 어댑터(`UserDefaultsKeyValueStore`)는 원시 `Data` 만 넘긴다. 인코딩·기본값 로직은 protocol extension 에 있어
  `InMemoryKeyValueStore` 로 테스트한다. 어댑터는 디스크에 쓰므로 단위 테스트하지 않는다.
- 값이 없으면 `SettingKey.defaultValue`, 해석하지 못하면 `.decodingFailed` 를 던진다.
- `UserDefaults` 는 SDK 에서 `Sendable` 이 아니라 인스턴스 대신 `suiteName` 만 보관한다.
- 키 이름은 쓰는 쪽(Data 의 Repository)이 `private enum` 에 모은다.
- UserDefaults 는 Required Reason API 다. 앱의 `PrivacyInfo.xcprivacy` 에 `CA92.1`(앱 전용)을 선언해 두었다.
  앱 그룹으로 공유하게 되면 `1C8F.1` 을 더한다.

### SwiftData

- `ModelContext` 와 `@Model` 인스턴스는 `Sendable` 이 아니다. `SwiftDataItemCache` 는 평범한 `actor` 로,
  첫 사용 때 자기 격리 안에서 `ModelContext` 를 만들고 모델을 밖으로 내보내지 않는다(`ItemCacheRecord` 로 바꾼다).
- `@ModelActor` 는 쓰지 않는다. main actor 에서 만들면 작업이 메인 스레드에서 돈다는 보고가 있고,
  `AppContainer` 는 `@MainActor` 다. 지금 방식은 main actor 에서 만들어도 작업이 메인 스레드 밖에서 도는 것을 확인했다.
  `-com.apple.CoreData.ConcurrencyDebug 1` 을 켠 채 `SwiftDataItemCacheTests` 가 위반 없이 통과하는 것도 확인했다.
- `replaceAll(with:)` 는 기존 항목을 모두 지우고 `position` 순서로 넣은 뒤 저장한다. `removeAll()` 은 지우고 저장한다.
  둘 다 실패하면 `rollback()` 한다.
- 겹치는 id 는 넣기 전에 처음 것만 남긴다. `@Attribute(.unique)` 가 겹치는 id 를 합치는 방식은 OS 버전마다 다를 수 있어
  직접 정한다(iOS 26 시뮬레이터에서도 실행마다 남는 쪽이 달랐다).
- iOS 18 전용 기능(`#Unique`, `#Index`, History)은 쓰지 않는다. 유니크 제약은 `@Attribute(.unique)` 다.
- 테스트는 `LocalDatabase(location: .inMemory)` 로 한다. 디스크를 쓰지 않는다.

## 새 모델을 더할 때

배포 전이라면 `PersistenceSchemaV1.models` 에 더한다. 배포한 뒤에는 V1 을 고치지 않고 아래 "스키마 버전 올리기"를 따른다.

1. `PersistenceSchemaV1+<Name>Entity.swift` 에 `@Model final class` 를 둔다(internal).
2. 공개할 것은 `Sendable` 레코드와 프로토콜뿐이다. 모델 인스턴스는 actor 밖으로 내보내지 않는다.
3. 구현 actor 는 `LocalDatabase` 를 받아 `SwiftDataItemCache` 처럼 컨텍스트를 lazy 로 만든다.
4. 테스트 대역을 `Testing/Sources/` 에 두고, 도메인 변환은 Data 에 둔다.

## 스키마 버전 올리기

1. `PersistenceSchemaV2` 를 새로 만든다. `versionIdentifier` 는 `Schema.Version(2, 0, 0)`, 모델 클래스는
   V2 안에 새로 선언한다(V1 의 클래스를 고치지 않는다).
2. `PersistenceMigrationPlan.schemas` 끝에 V2 를 더하고, `stages` 에 `.lightweight(fromVersion:toVersion:)` 나
   `.custom(...)` 단계를 더한다.
3. `LocalDatabase` 와 구현 actor 가 참조하는 스키마·모델을 V2 로 바꾼다.
4. V1 저장소 파일에서 V2 로 여는 테스트를 더한다.

디스크 저장소는 `AppContainer.init`(main actor)에서 동기로 연다. 이동 단계가 비어 있는 지금은 가볍지만,
`.custom` 단계처럼 오래 걸리는 이동을 더하면 앱 시작이 늦어지고 시작 watchdog 에 걸릴 수 있다.
그런 단계를 더할 때는 저장소 열기를 시작 경로 밖(첫 사용 시점 또는 백그라운드)으로 옮기는 것부터 정한다.

## 주의

- 캐시 만료·신선도 정책은 아직 없다. 원격이 `.unavailable` 일 때 마지막 결과를 그대로 돌려준다.
- 로그인 상태가 아니게 되면(로그아웃·만료) App 이 Data 의 `CachedItemRepository.clearCache()` 로 캐시를 비운다.
  원격이 401 도 `.unavailable` 로 올리므로 비우지 않으면 이전 계정의 항목이 보인다.
  Keychain 을 읽지 못해도(예: 첫 잠금 해제 전 백그라운드 실행) 첫 상태가 `.signedOut` 이라 로그인한 사용자의 캐시도
  비워진다. 그 상태에서는 원격도 인증할 수 없어 잃는 것은 캐시뿐이다.
- 비우기와 쓰기는 Data 의 `ItemCacheWriter` 가 요청 시작 순서로 판단하고, 캐시 호출도 그 순서대로 하나씩 실행한다.
  `ItemCache` 구현 안에 중단 지점이 있거나 호출 우선순위가 달라도 비운 캐시에 이전 요청의 목록이 다시 쓰이지 않는다.
- 저장소는 앱 그룹·CloudKit 을 쓰지 않는다고 명시한다(`groupContainer: .none`, `cloudKitDatabase: .none`).
  `.automatic` 이면 앱 그룹 엔타이틀먼트를 더하는 순간 위치가 그룹 컨테이너로 바뀌어 기존 캐시를 잃는다.
  공유가 필요해지면 이동 절차와 함께 따로 정한다.
- 디스크 저장소를 열지 못하면 App 이 보고하고 메모리 저장소로 연다. 이때 캐시는 앱 수명 동안만 남는다.
- 기기에는 Application Support 의 저장소 파일(`Persistence.store`)과 `persistence.` 접두사 UserDefaults 키가 남는다.
  저장소 파일 이름은 배포한 뒤에 바꾸지 않는다(바꾸면 기존 캐시를 잃는다).
