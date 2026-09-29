# 로컬 저장소(Persistence 모듈): 설정값과 Item 오프라인 캐시

## 목표

- 새 Core 모듈 `Persistence` 가 있고, 이 모듈은 Foundation, SwiftData 외에는 import 하지 않는다(Domain 을 모른다).
  - 키-값 저장: `KeyValueStore` 프로토콜과 `UserDefaultsKeyValueStore` 구현, 타입 있는 키(`SettingKey<Value>`).
  - 구조화 저장: `LocalDatabase`(SwiftData `ModelContainer` 래퍼, V1 버전 스키마), `ItemCache` 프로토콜과
    `SwiftDataItemCache` 구현.
  - `PersistenceTesting` 에 `InMemoryKeyValueStore`, `InMemoryItemCache`, `FailingItemCache` 가 있다.
- Domain 에 `SettingsRepository`(예시 설정: 온보딩 완료 여부)가 있고, Data 의 `LocalSettingsRepository` 가 이를 구현한다.
- Data 의 `CachedItemRepository` 가 `RemoteItemRepository` 를 감싼다. 원격 호출이 성공하면 캐시를 갱신하고,
  원격이 `.unavailable` 이면 캐시된 항목을 돌려준다(테스트로 고정).
- `AppContainer` 가 둘을 조립해 `itemRepository`(캐시 적용), `settingsRepository` 로 노출한다.
- `App/Resources/PrivacyInfo.xcprivacy` 에 UserDefaults 사용 사유 `CA92.1` 이 선언돼 있다.
- `./.claude/scripts/xcbuild.sh test`, `build`, `build -configuration Release`, `swiftformat --lint .`,
  `swiftlint lint --quiet` 가 통과한다. 각 단계 커밋마다 통과한다.

## 범위 밖

- 설정·캐시를 쓰는 화면(온보딩 피처, 오프라인 배너). 이번에는 Repository 와 조립까지만 한다.
- 캐시 만료·신선도 정책(시각 기록, TTL). 시계 의존이 생기므로 따로 다룬다.
- 앱 그룹 공유(`1C8F.1`, App Group 컨테이너), CloudKit 동기화.
- iOS 18 전용 SwiftData 기능(`#Unique`, `#Index`, `HistoryDescriptor`, `DataStore`). 가용성 분기를 만들지 않는다.
- 스키마 V2 와 실제 마이그레이션 단계. V1 과 빈 `SchemaMigrationPlan` 틀만 둔다.
- Keychain 변경. 비밀값은 계속 `Auth` 의 `KeychainTokenStore` 가 맡는다.
- 새 외부 의존성.

## 전제

구현 세션은 이 문서만 읽습니다.

### 버전과 환경
- iOS 17.0(`Tuist/ProjectDescriptionHelpers/AppConstants.swift:20`), Swift 6.0 언어 모드, Tuist 4.208.0.
  `enforceExplicitDependencies` 가 켜져 있어 import 하는 모듈은 해당 타깃의 `*Dependencies` 에 모두 적는다.
- 쓰는 API 는 모두 iOS 17 이하에서 쓸 수 있다. 가용성 분기는 필요 없다.

| API | 도입 | 비고 | 출처 |
| --- | --- | --- | --- |
| `ModelContainer` (Sendable) | iOS 17 | `init(for: Schema, migrationPlan:, configurations:)` | https://developer.apple.com/documentation/swiftdata/modelcontainer |
| `ModelContext` (Sendable 아님) | iOS 17 | actor 안에서만 만들고 쓴다 | https://developer.apple.com/documentation/swiftdata/modelcontext |
| `ModelConfiguration(isStoredInMemoryOnly:)` | iOS 17 | 테스트와 폴백용 in-memory 저장소 | https://developer.apple.com/documentation/swiftdata/modelconfiguration |
| `VersionedSchema`, `SchemaMigrationPlan` | iOS 17 | V1 부터 시작 | https://developer.apple.com/documentation/swiftdata/versionedschema |
| `@Attribute(.unique)` | iOS 17 | `#Unique`(iOS 18) 대신. 도입 버전은 구현 중 문서로 확인 | https://developer.apple.com/documentation/swiftdata/schema/attribute/option/unique |
| `FetchDescriptor`, `SortDescriptor` | iOS 17 | | https://developer.apple.com/documentation/swiftdata/fetchdescriptor |
| `UserDefaults` | iOS 2 | thread-safe. Swift 6 SDK 에서 `Sendable` 인지는 구현 중 확인 | https://developer.apple.com/documentation/foundation/userdefaults |

### 현재 코드 (2026-09-28, main `3d06eec`)

| 파일:줄 | 내용 |
| --- | --- |
| `Tuist/ProjectDescriptionHelpers/Module.swift:152-165` | `Module.all`. `new-module.sh` 가 164행 마커 위에 `.core("<Name>")` 를 넣는다 |
| `Tuist/ProjectDescriptionHelpers/Module.swift:204-226` | `mayDepend(on:)`. `(.data, …)` 규칙은 216-220행. 없는 조합은 generate 가 문구 없이 멈춘다 |
| `Tuist/ProjectDescriptionHelpers/Module.swift:85-87` | 이름 있는 case 는 여러 쌍에 규칙이 필요할 때만 만든다. Persistence 는 Data 만 의존하므로 `.core("Persistence")` 로 둔다 |
| `Tuist/ProjectDescriptionHelpers/Module.swift:17-32` | 의존 방향 그림 주석. Data → Persistence 를 더한다 |
| `Modules/Core/Data/Project.swift:13-30` | Data 의 `dependencies`/`testDependencies` |
| `Modules/Core/Auth/Sources/TokenStore.swift:9` | 로컬 저장 선례: `protocol …: Sendable` + 구현 + `*Error` + `*Testing` 더블 |
| `Modules/Core/Auth/Project.swift:9-17` | 모듈 문서 주석 형식(import 허용 범위, Testing 내용) |
| `Modules/Core/Domain/Sources/ItemRepository.swift` | `fetchItems() async throws(ItemError) -> [Item]` |
| `Modules/Core/Domain/Sources/ItemError.swift` | `.unavailable`, `.invalidData` |
| `Modules/Core/Domain/Sources/Item.swift` | `struct Item { id: String, title: String }` |
| `Modules/Core/Domain/Testing/Sources/StubItemRepository.swift` | Data 테스트에서 원격 대역으로 재사용 |
| `Modules/Core/Data/Sources/RemoteItemRepository.swift:18` | 보고 규칙: `catch` 에서 삼키지 않고 `reporter` 로 보고 |
| `Modules/Core/Diagnostics/Sources/DiagnosticReporting.swift:9` | `report(_ failure: DiagnosticFailure)`. 비동기로 보고하고 기다리지 않는다 |
| `Modules/Core/Diagnostics/Sources/DiagnosticFailure.swift:21` | `init(operationID:errorType:errorCode:summary:requestID:)` |
| `App/Sources/DI/AppContainer.swift:18-21` | 구현 타입 목록 문서 주석. 새 구현 타입을 더한다 |
| `App/Sources/DI/AppContainer.swift:36-82` | `init`. `bundleIdentifier` guard(40행) 뒤에 만든다. `itemRepository` 는 80행 |
| `App/Project.swift:15-27` | 앱 `dependencies`. `.module(.core("Push"))` 형식 |
| `App/Resources/PrivacyInfo.xcprivacy` | `NSPrivacyAccessedAPITypes` 가 빈 배열이다 |
| `Scripts/new-module.sh` | `core <Name> --testing`. `swiftdata`, `coredata` 는 예약어라 모듈명으로 못 쓴다 |

### 알려진 함정
- **`ModelContext` 와 `@Model` 인스턴스는 Sendable 이 아니다.** actor 밖으로 내보내지 않고 `ItemCacheRecord`
  (Sendable struct)로 바꿔 돌려준다. Domain 은 Foundation 만 import 하므로 `PersistentIdentifier` 도 넘기지 않는다.
- **`@ModelActor` 를 main actor 에서 만들면 작업이 메인 스레드에서 돈다는 보고가 있다**(공식 문서로 확인하지 못함).
  `AppContainer` 는 `@MainActor` 이므로 `@ModelActor` 를 쓰지 않는다(결정 사항 참고).
- **Swift 6 전역 상태**: `VersionedSchema.versionIdentifier` 를 `static var` 저장 프로퍼티로 두면 동시성 에러가 난다.
  `static let` 이나 계산 프로퍼티로 둔다. `models` 도 계산 프로퍼티로 둔다.
- **Privacy manifest**: `UserDefaults` 는 Required Reason API 다. `NSPrivacyAccessedAPICategoryUserDefaults` + `CA92.1`
  (앱 전용). 파일 타임스탬프 API 는 쓰지 않으므로 `C617.1` 은 필요 없다. 출처:
  https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
- **UserDefaults 는 암호화하지 않고 백업에 포함된다.** 비밀값을 여기 두지 않는다고 `KeyValueStore` 문서 주석에 적는다.
- **테스트 규약상 디스크에 의존할 수 없다.** SwiftData 는 in-memory 설정으로 테스트한다. `UserDefaultsKeyValueStore` 는
  UserDefaults 에 그대로 넘기기만 하는 얇은 어댑터로 두고 단위 테스트하지 않는다. 인코딩·기본값 로직은 그 위의 계층에
  두고 `InMemoryKeyValueStore` 로 테스트한다.
- 스키마 변경은 배포 후 `VersionedSchema` 를 추가해야 한다. 처음부터 V1 로 선언한다.

## 결정 사항

| 결정 | 선택 | 이유 |
| --- | --- | --- |
| 범위 | 설정값(UserDefaults) + 구조화 데이터(SwiftData) 둘 다 | 사용자 결정. 템플릿에서 두 패턴을 모두 보여 준다 |
| 모듈 위치 | 새 Core 모듈 `Persistence`, 등록은 `.core("Persistence")` | 사용자 결정. `Auth` 선례처럼 저장 기술을 한 모듈에 가둔다. Data 가 Networking 과 SwiftData 를 함께 알지 않게 한다 |
| 플랫폼 조사와의 충돌 | 플랫폼 조사는 SwiftData 를 Data 안에 두라고 했다. Persistence 로 분리해 Data 는 Persistence 의 프로토콜만 쓴다 | Domain 의존성을 SwiftData 에서 떼어 놓는다는 조사 권고의 목적은 그대로 지킨다 |
| 의존 규칙 | `(.data, .core("Persistence"))` 만 더한다. Persistence 는 아무 모듈에도 의존하지 않는다. App 은 규칙 없이 의존한다 | Persistence 가 Domain 을 모르게 해야 `Item` 매핑이 Data 한 곳에 모인다 |
| SwiftData 예시 | `Item` 오프라인 캐시 | 사용자 결정. 기존 `Item`/`ItemRepository` 를 재사용하므로 Domain 변경이 없다 |
| 캐시 계층 | Data 의 `CachedItemRepository: ItemRepository` 가 `remote: any ItemRepository` 와 `cache: any ItemCache` 를 감싼다 | 데코레이터라 `RemoteItemRepository` 와 UseCase 를 고치지 않는다 |
| 캐시 정책 | 원격 성공 → 캐시를 통째로 교체하고 원격 결과 반환. 원격 `.unavailable` → 캐시가 비어 있지 않으면 캐시 반환, 비어 있으면 `.unavailable`. 원격 `.invalidData` → 캐시로 넘어가지 않고 그대로 던진다. 호출이 취소됐으면 캐시를 읽지 않고 그대로 던진다(리뷰 R1-4) | 서버가 응답했는데 해석하지 못한 경우를 오래된 데이터로 가리지 않는다. 취소된 호출의 결과는 버려진다 |
| 로그아웃 시 캐시 (리뷰 R1-1) | `ItemCache.removeAll()` 과 `CachedItemRepository.clearCache()` 를 두고, App 이 세션 상태가 `.signedOut`·`.expired` 가 될 때마다 비운다(앱 시작 때 첫 상태가 `.signedOut` 이어도 비운다) | 원격이 401 도 `.unavailable` 로 올리므로 비우지 않으면 로그아웃 뒤나 다른 계정에서 이전 계정의 항목이 보인다. `ItemError.unauthorized` 를 두는 대안은 Domain 변경이라 범위가 크다 |
| 캐시 쓰기 순서 (리뷰 R1-5, R2-1, R2-2, R3-1) | Data 의 `ItemCacheWriter`(actor)가 요청 시작 번호를 나눠 주고, 이미 쓴 요청보다 먼저 시작한 요청의 쓰기와 비우기 전에 시작한 요청의 쓰기를 버린다. 판단은 호출 시점에 하고 실제 캐시 호출은 그 순서대로 하나씩 실행한다. 기준은 성공한 번호·진행 중인 번호·비우기 기준의 최댓값으로 매번 계산해, 실패한 쓰기가 기준에 남지 않게 한다(리뷰 R3-1). 순서 보장은 쓰기·비우기에만 적용하고 읽기는 줄을 거치지 않는다 | 겹친 요청에서 오래된 목록이 남거나, 로그아웃 전에 시작한 요청이 비운 캐시를 되살리는 것을 막는다 |
| 캐시 실패 처리 | 쓰기 실패: 보고하고 원격 결과를 그대로 돌려준다. 읽기 실패: 보고하고 원래 에러(`.unavailable`)를 던진다 | 캐시는 부가 기능이다. 캐시 실패가 성공한 원격 결과를 망치지 않게 한다. `catch` 에서 삼키지 않고 보고한다 |
| 순서 보존 | `ItemEntity` 에 `position: Int` 를 두고 그 순서로 읽는다 | 원격이 준 순서를 캐시에서도 재현한다. 화면 정렬은 여전히 UseCase 가 한다 |
| 겹치는 id (리뷰 R1-3) | `replaceAll` 이 넣기 전에 처음 나온 것만 남긴다(`removingDuplicateIDs()`) | `@Attribute(.unique)` 의 합치는 방식이 OS 버전마다 다를 수 있다. 규칙을 SwiftData 밖 함수로 두어 직접 테스트한다 |
| 유니크 제약 | `@Attribute(.unique) var id: String` | `#Unique` 는 iOS 18. `replaceAll` 이 전부 지우고 넣으므로 충돌은 원격 중복 id 때만 생긴다 |
| SwiftData 동시성 | `@ModelActor` 대신 평범한 `actor SwiftDataItemCache` 가 첫 사용 때 자기 격리 안에서 `ModelContext(container)` 를 lazy 로 만든다 | `@MainActor` 인 `AppContainer` 에서 만들어도 컨텍스트가 메인 스레드에 묶이지 않는다. `@unchecked Sendable` 이 필요 없다 |
| 컨테이너 노출 | `public struct LocalDatabase: Sendable`(내부에 `ModelContainer`)를 `init(location: .onDisk / .inMemory) throws(PersistenceError)` 로 만든다 | App 과 Data 가 SwiftData 를 import 하지 않아도 된다. 여러 캐시가 한 컨테이너를 공유할 수 있다 |
| 저장소 파일 이름 (리뷰 R1-6, R2-6) | 디스크 저장소는 `ModelConfiguration("Persistence", …)` 로 `Persistence.store` 에 둔다. in-memory 는 이름을 주지 않는다. 둘 다 `groupContainer: .none`, `cloudKitDatabase: .none` 을 명시한다 | 기본 `default.store` 는 다른 SwiftData 사용과 충돌할 수 있다. 첫 배포 전이 이름을 고정하기 가장 싼 때다. `.automatic` 이면 앱 그룹·iCloud 엔타이틀먼트가 붙는 순간 위치가 바뀌거나 열기가 실패한다 |
| 디스크 저장소 열기 실패 | `AppContainer` 가 실패를 보고하고 `.inMemory` 로 다시 연다 | 캐시 때문에 앱 실행이 막히면 안 된다. 폴백해도 실패는 보고로 남는다 |
| 키-값 계층 | `protocol KeyValueStore: Sendable { data(forKey:) -> Data?; set(_:forKey:); removeValue(forKey:) }` + `SettingKey<Value: Codable & Sendable>`(이름, 기본값) + `KeyValueStore` extension 의 `value(for:) throws(PersistenceError)` / `setValue(_:for:) throws(PersistenceError)` 가 JSON 인코딩을 맡는다 | 원시 저장만 어댑터에 두어 인코딩 로직을 in-memory 로 테스트할 수 있다. 값이 없으면 기본값을 돌려준다 |
| UserDefaults 키 | 모든 키 앞에 접두사 상수(예: `"persistence."`)를 붙이고, 접두사는 `private enum` 에 둔다 | Firebase 같은 SDK 가 쓰는 키와 섞이지 않게 한다. 리터럴을 흩어 두지 않는다 |
| `UserDefaults` 보관 | `UserDefaults` 가 SDK 에서 `Sendable` 이면 인스턴스를 보관한다. 아니면 `suiteName: String?` 만 보관하고 호출할 때마다 `UserDefaults(suiteName:)` 로 얻는다. 구현 중 확인 | `@unchecked Sendable` 금지 규약을 지킨다 |
| 설정 예시 | Domain `protocol SettingsRepository: Sendable { hasCompletedOnboarding() -> Bool; setHasCompletedOnboarding(_:) }`. 저장된 값을 해석하지 못하면 Data 가 보고하고 기본값 `false` 를 돌려준다 | 템플릿에서 흔히 필요한 예시다. 화면이 설정 에러를 구분할 이유가 없으므로 Domain 에 에러 타입을 늘리지 않는다 |
| 보고 형식 | `DiagnosticFailure(operationID: nil, errorType: "PersistenceError", errorCode: nil, summary: <case 이름>, requestID: nil)`. 문자열은 Data 의 `private enum` 상수로 둔다. `reportPersistenceFailure(_:)` 는 `public` 이라 App 의 저장소 폴백도 같은 형식으로 보고한다 | 기존 Diagnostics 경로를 재사용한다. 새 보고 API 를 만들지 않는다 |

## 변경 계획

### 1. Persistence 모듈 생성과 등록
- 실행: `Scripts/new-module.sh core Persistence --testing`
- 파일: `Modules/Core/Persistence/Project.swift`
  - 변경: `Auth/Project.swift` 형식으로 문서 주석을 단다(Foundation, SwiftData 외 import 금지, Domain 을 모른다,
    비밀값은 Auth 의 Keychain 에 둔다, Testing 에 들어갈 더블 목록).
- 파일: `Tuist/ProjectDescriptionHelpers/Module.swift`
  - 변경: `Module.all` 에 `.core("Persistence")` 가 들어갔는지 확인한다(스크립트가 넣는다). `mayDepend(on:)` 216-220행에
    `(.data, .core("Persistence"))` 를 더한다. 17-32행 그림에 `Data ──→ Persistence` 를 더한다.
    `.core("Persistence")` 가 switch 의 튜플 패턴에서 매치되는지는 구현 중 확인하고, 안 되면
    `case let (.data, .core(name)) where name == …` 형식으로 쓴다.
- 파일: `Modules/Core/Data/Project.swift`
  - 변경: `dependencies` 와 `testDependencies` 에 `.module(.core("Persistence"))`, `testDependencies` 에
    `.testing(.core("Persistence"))`, `.testing(.domain)` 을 더한다(이미 있으면 그대로 둔다).
- 검증: `tuist generate` 가 성공하고 `xcbuild.sh build`, `xcbuild.sh test` 가 통과한다. 템플릿 placeholder 테스트가 돈다.

### 2. Persistence: 키-값 저장소
- 파일: `Modules/Core/Persistence/Sources/PersistenceError.swift`
  - 변경: `public enum PersistenceError: Error, Equatable, Sendable`. 최소 `.encodingFailed`, `.decodingFailed`,
    `.storeUnavailable`, `.operationFailed`. 원인 에러는 Equatable 을 위해 담지 않고, 필요하면 문자열 설명만 담는다.
- 파일: `Sources/KeyValueStore.swift`, `Sources/SettingKey.swift`, `Sources/KeyValueStore+Codable.swift`,
  `Sources/UserDefaultsKeyValueStore.swift`
  - 변경: 결정 사항의 키-값 계층. `SettingKey` 는 `public struct SettingKey<Value: Codable & Sendable>: Sendable`
    (`name`, `defaultValue`). 값이 없으면 `defaultValue`, 해석에 실패하면 `.decodingFailed` 를 던진다.
    `UserDefaultsKeyValueStore` 는 접두사를 붙여 UserDefaults 에 그대로 넘긴다.
- 파일: `Modules/Core/Persistence/Testing/Sources/InMemoryKeyValueStore.swift`
  - 변경: `KeyValueStore` 는 동기 프로토콜이라 actor 로 구현할 수 없고, `Mutex` 는 iOS 18 부터다.
    `OSAllocatedUnfairLock<[String: Data]>`(iOS 16, `os` 모듈)로 상태를 감싼 `final class InMemoryKeyValueStore: KeyValueStore`
    로 만든다. `Project.swift` 문서 주석에 Testing 타깃은 `os` 를 import 한다고 적는다. 락 타입의 Sendable 여부는 구현 중 확인.
- 파일: `Modules/Core/Persistence/Tests/KeyValueStoreCodableTests.swift`
- 검증: 아래 테스트 전략의 키-값 테스트가 통과한다.

### 3. Persistence: SwiftData 캐시
- 파일: `Sources/PersistenceSchemaV1.swift`
  - 변경: `enum PersistenceSchemaV1: VersionedSchema`. `versionIdentifier` 는 `Schema.Version(1, 0, 0)`,
    `models` 는 계산 프로퍼티. 안에 `@Model final class ItemEntity { @Attribute(.unique) var id: String; var title: String;
    var position: Int }` (internal). 파일 한 개 한 타입 규약상 `ItemEntity` 는 extension 으로 `PersistenceSchemaV1+ItemEntity.swift`
    에 둔다.
- 파일: `Sources/PersistenceMigrationPlan.swift`
  - 변경: `enum PersistenceMigrationPlan: SchemaMigrationPlan`, `schemas = [PersistenceSchemaV1.self]`, `stages = []`.
- 파일: `Sources/LocalDatabase.swift`
  - 변경: `public struct LocalDatabase: Sendable`, `public enum Location { case onDisk, inMemory }`,
    `public init(location:) throws(PersistenceError)`. 실패는 `.storeUnavailable` 로 바꾼다. 컨테이너는 `internal`.
- 파일: `Sources/ItemCacheRecord.swift`, `Sources/ItemCache.swift`, `Sources/SwiftDataItemCache.swift`
  - 변경: `public struct ItemCacheRecord: Sendable, Equatable { id, title }`.
    `public protocol ItemCache: Sendable { load() async throws(PersistenceError) -> [ItemCacheRecord];
    replaceAll(with:) async throws(PersistenceError) }`.
    `public actor SwiftDataItemCache: ItemCache` 는 `init(database:)`, lazy `ModelContext`, `replaceAll` 에서 기존 항목을
    모두 지우고 `position` 순서대로 넣은 뒤 `save()`. `load` 는 `position` 오름차순 `FetchDescriptor`.
    SwiftData 에러는 `.operationFailed` 로 바꾼다.
- 파일: `Testing/Sources/InMemoryItemCache.swift`(actor, `replaceAllCount` 기록), `Testing/Sources/FailingItemCache.swift`
  (load·replaceAll 이 주어진 `PersistenceError` 를 던진다)
- 파일: `Tests/SwiftDataItemCacheTests.swift`
- 검증: in-memory `LocalDatabase` 로 테스트가 통과한다. 구현 중에 `SwiftDataItemCache` 의 작업이 메인 스레드 밖에서 도는지
  테스트나 디버거로 한 번 확인하고 결과를 커밋 메시지에 남긴다.

### 4. Domain·Data: 설정 Repository
- 파일: `Modules/Core/Domain/Sources/SettingsRepository.swift`
  - 변경: 결정 사항의 프로토콜. 문서 주석에 구현(`LocalSettingsRepository`)과 스텁 위치를 적는다(`ItemRepository.swift` 형식).
- 파일: `Modules/Core/Domain/Testing/Sources/StubSettingsRepository.swift`
- 파일: `Modules/Core/Data/Sources/LocalSettingsRepository.swift`
  - 변경: `init(store: any KeyValueStore, reporter: any DiagnosticReporting)`. `private enum SettingKeys` 에
    `static let hasCompletedOnboarding = SettingKey<Bool>(name: …, defaultValue: false)`.
    읽기·쓰기 실패는 보고한다. 읽기 실패는 기본값을 돌려주고, 쓰기 실패는 보고만 한다(Bool 인코딩은 실제로 실패하지 않는다고 주석).
- 파일: `Modules/Core/Data/Sources/DiagnosticReporting+PersistenceError.swift`
  - 변경: `reportPersistenceFailure(_ error: PersistenceError)`. `DiagnosticReporting+NetworkFailure.swift` 형식.
- 파일: `Modules/Core/Data/Tests/LocalSettingsRepositoryTests.swift`
- 검증: 테스트 통과, `build` 통과.

### 5. Data: Item 캐시 데코레이터
- 파일: `Modules/Core/Data/Sources/CachedItemRepository.swift`
  - 변경: `public struct CachedItemRepository: ItemRepository`, `init(remote: any ItemRepository, cache: any ItemCache,
    reporter: any DiagnosticReporting)`. 결정 사항의 캐시 정책. `Item` ↔ `ItemCacheRecord` 변환은
    `Sources/ItemCacheRecord+Domain.swift` 에 둔다(`Components.Schemas.Item+Domain.swift` 형식).
- 파일: `Modules/Core/Data/Tests/CachedItemRepositoryTests.swift`
- 검증: 테스트 통과.

### 6. App 조립과 Privacy manifest
- 파일: `App/Project.swift`
  - 변경: 앱 `dependencies` 에 `.module(.core("Persistence"))`.
- 파일: `App/Sources/DI/AppContainer.swift`
  - 변경: `import Persistence`. `bundleIdentifier` guard 뒤, `diagnosticReporter` 를 만든 뒤에
    `LocalDatabase(location: .onDisk)` 를 열고 실패하면 보고한 뒤 `.inMemory` 로 연다(in-memory 도 실패하면
    `preconditionFailure` 로 이유를 남긴다). 80행을
    `CachedItemRepository(remote: RemoteItemRepository(…), cache: SwiftDataItemCache(database:), reporter:)` 로 바꾼다.
    `let settingsRepository: any SettingsRepository` 를 더하고 `LocalSettingsRepository(store: UserDefaultsKeyValueStore(),
    reporter:)` 로 채운다. 18-21행 구현 타입 목록에 새 타입을 더한다.
- 파일: `App/Resources/PrivacyInfo.xcprivacy`
  - 변경: `NSPrivacyAccessedAPITypes` 에 `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` 항목을 넣는다.
    파일 상단 주석에 어떤 모듈이 이 API 를 쓰는지 한 줄 더한다.
- 파일: 모듈 문서. Auth 도입 때(`89d2e65`) 문서를 더한 위치를 확인하고 같은 곳에 Persistence 설명(새 모델 추가 방법,
  스키마 버전 올리는 법)을 둔다. 위치는 구현 중 확인.
- 검증: `build`, `build -configuration Release`, `test`, `swiftformat --lint .`, `swiftlint lint --quiet` 통과.
  시뮬레이터에서 앱을 실행해 시작 시 크래시가 없는지 확인한다.

## 테스트 전략

모두 Swift Testing(`@Test`, `#expect`, `#require`)으로 쓰고, 이름은 `동작_조건_기대결과` 형식을 따른다. 디스크를 쓰지 않는다.

**Persistence / `KeyValueStoreCodableTests`** (`InMemoryKeyValueStore` 사용)
- 값이 없으면 기본값을 돌려준다.
- 저장한 값을 다시 읽으면 같은 값이다(Bool, Codable struct).
- 해석할 수 없는 Data 가 있으면 `.decodingFailed` 를 던진다.
- `removeValue` 후에는 기본값을 돌려준다.

**Persistence / `SwiftDataItemCacheTests`** (in-memory `LocalDatabase`)
- 비어 있는 캐시에서 `load` 하면 빈 배열이다.
- `replaceAll` 한 뒤 `load` 하면 넣은 순서 그대로다.
- 두 번 `replaceAll` 하면 두 번째 목록만 남는다.
- 서로 다른 `SwiftDataItemCache` 두 개가 같은 `LocalDatabase` 를 공유하면 한쪽이 쓴 것을 다른 쪽이 읽는다.

**Data / `LocalSettingsRepositoryTests`** (`InMemoryKeyValueStore`, `SpyDiagnosticReporter`)
- 처음에는 `hasCompletedOnboarding()` 이 `false` 다.
- `setHasCompletedOnboarding(true)` 후 `true` 다.
- 저장된 값이 깨져 있으면 `false` 를 돌려주고 보고를 한 번 남긴다.

**Data / `CachedItemRepositoryTests`** (`StubItemRepository`, `InMemoryItemCache`, `FailingItemCache`, `SpyDiagnosticReporter`)
- 원격이 성공하면 원격 결과를 돌려주고 캐시를 그 결과로 교체한다.
- 원격 `.unavailable` 이고 캐시가 있으면 캐시 항목을 돌려준다.
- 원격 `.unavailable` 이고 캐시가 비어 있으면 `.unavailable` 을 던진다.
- 원격 `.invalidData` 면 캐시가 있어도 `.invalidData` 를 던진다.
- 원격이 성공하고 캐시 쓰기가 실패하면 원격 결과를 돌려주고 보고를 한 번 남긴다.
- 원격 `.unavailable` 이고 캐시 읽기가 실패하면 `.unavailable` 을 던지고 보고를 한 번 남긴다.

**수정할 기존 테스트**: 없음. `RemoteItemRepositoryTests`, `DefaultFetchItemsUseCaseTests` 는 바뀌지 않는다.
`AppContainer` 의 저장소 폴백 분기를 정적 팩토리로 뽑을 수 있으면(`makeDiagnosticSink` 선례)
`AppContainerLocalDatabaseTests` 를 더한다. 뽑을지는 구현 중 판단한다.

## 위험 요소

| 위험 | 가능성 | 대응 |
| --- | --- | --- |
| `@Model` 매크로가 Swift 6 strict concurrency 에서 경고·에러를 낸다 | 중 | 모델을 actor 밖으로 내보내지 않는다. 그래도 진단이 나면 억제하지 말고 원인과 함께 멈추고 보고한다 |
| lazy `ModelContext` 방식에서도 작업이 메인 스레드에서 돈다 | 낮 | 3단계 검증에서 확인한다. 그러면 `Task.detached` 안에서 캐시를 만드는 팩토리로 바꾼다 |
| `UserDefaults` 가 SDK 에서 Sendable 이 아니다 | 중 | 결정 사항의 `suiteName` 보관 폴백을 쓴다 |
| `OSAllocatedUnfairLock` 사용이 테스트 더블에 과하다 | 낮 | `KeyValueStore` 를 async 로 바꾸고 `InMemoryKeyValueStore` 를 actor 로 만드는 대안이 있다. 바꾸면 이 문서의 결정 사항을 고친다 |
| iOS 17.x SwiftData 버그(릴리스 노트는 조사하지 않음) | 중 | 테스트는 in-memory 라 잡지 못할 수 있다. 6단계에서 시뮬레이터로 한 번 실행한다. iOS 17 시뮬레이터가 없으면 그렇다고 기록한다 |
| `mayDepend` 규칙 누락으로 generate 가 문구 없이 멈춘다 | 중 | 1단계에서 generate 를 먼저 돌린다. 문구는 오류에 찍힌 `xcrun swift … --tuist-dump` 로 본다 |
| 디스크 저장소가 열리지 않아 매번 in-memory 로 떨어진다 | 낮 | 보고로 드러난다. 캐시가 없을 뿐 앱 동작은 원격만 쓸 때와 같다 |
| 배포 후 스키마 변경 시 마이그레이션 누락 | 중 | V1 버전 스키마와 빈 마이그레이션 계획을 처음부터 두고, 모듈 문서에 V2 추가 절차를 적는다 |

## 롤백

- 단계별 커밋이므로 역순으로 `git revert` 한다. 6단계만 되돌리면 앱은 `RemoteItemRepository` 를 직접 쓰는 이전 동작으로
  돌아가고, Persistence 모듈은 남아도 앱에 링크되지 않는다.
- 이미 배포한 뒤 되돌리면 기기에 SwiftData 저장소 파일(Application Support 의 `Persistence.store`)과
  `persistence.` 접두사 UserDefaults 키가 남는다. 둘 다 캐시·설정이라 남아도 동작에 영향이 없다. 지우려면 정리 코드를 따로 배포한다.
- Privacy manifest 의 `CA92.1` 항목은 UserDefaults 를 쓰는 코드가 모두 빠질 때 함께 뺀다.
