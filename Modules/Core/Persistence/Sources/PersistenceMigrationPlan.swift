//
//  PersistenceMigrationPlan.swift
//  Persistence
//

import SwiftData

/// 스키마 버전 목록과 버전 사이 이동 단계. 새 버전은 `schemas` 끝에 더하고, 이전 버전에서 오는 단계를 `stages` 에 더한다.
enum PersistenceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PersistenceSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
