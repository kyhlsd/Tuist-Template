//
//  Project.swift
//  TuistAppManifests
//

import ProjectDescription
import ProjectDescriptionHelpers

/// 기기 안 저장소. 키-값 설정(`KeyValueStore`, `UserDefaultsKeyValueStore`, `SettingKey`)과
/// 구조화 데이터(`LocalDatabase`, `ItemCache`, `SwiftDataItemCache`)와 그 에러(`PersistenceError`).
/// Foundation, SwiftData 외에는 import 하지 않는다. Domain 을 모르므로 엔티티 변환은 Data 가 맡는다.
/// 비밀값(토큰 등)은 여기 두지 않고 Auth 의 `KeychainTokenStore` 에 둔다.
///
/// PersistenceTesting 에는 `InMemoryKeyValueStore`, `InMemoryItemCache`, `FailingItemCache` 를 둔다.
/// Data 테스트가 재사용한다. `InMemoryKeyValueStore` 의 락 때문에 Testing 타깃은 `os` 도 import 한다.
let project = Project.core(
    name: "Persistence",
    testDependencies: [
        .testing(.core("Persistence")), // 테스트가 자기 픽스처·대역을 쓴다
    ],
    hasTestingSupport: true
)
