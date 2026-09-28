//
//  PersistenceSchemaV1.swift
//  Persistence
//

import SwiftData

/// 첫 배포 스키마. 배포한 뒤에는 고치지 않는다.
///
/// 모델을 바꾸려면 `PersistenceSchemaV2` 를 새로 만들고 `PersistenceMigrationPlan` 에 스키마와 단계를 더한다.
enum PersistenceSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ItemEntity.self]
    }
}
