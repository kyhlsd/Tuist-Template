//
//  LocalDatabase.swift
//  Persistence
//

import SwiftData

/// 구조화 데이터 저장소. SwiftData 의 `ModelContainer` 를 감싸 App 과 Data 가 SwiftData 를 모르게 한다.
///
/// 한 인스턴스를 여러 캐시가 공유할 수 있다. 앱은 `.onDisk` 를, 테스트는 `.inMemory` 를 쓴다.
public struct LocalDatabase: Sendable {
    /// 저장 위치.
    public enum Location: Sendable {
        /// Application Support 의 `Persistence.store`. 다른 SwiftData 사용이 쓰는 기본 파일(`default.store`)과 겹치지 않게
        /// 이름을 고정한다. 배포한 뒤에는 바꾸지 않는다(바꾸면 기존 캐시를 잃는다).
        case onDisk
        /// 프로세스가 끝나면 사라진다. 테스트와 디스크 저장소를 열지 못했을 때의 폴백에 쓴다.
        case inMemory
    }

    let container: ModelContainer

    /// - Throws: 저장소를 열 수 없으면 `.storeUnavailable`.
    public init(location: Location) throws(PersistenceError) {
        let schema = Schema(versionedSchema: PersistenceSchemaV1.self)
        let configuration = switch location {
        case .onDisk:
            ModelConfiguration(StoreName.onDisk, schema: schema)
        case .inMemory:
            // 이름을 주지 않는다. 컨테이너마다 따로인 저장소라 테스트끼리 섞이지 않는다.
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: PersistenceMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            // 원인은 PersistenceError 의 Equatable 을 위해 담지 않는다. 보고는 부르는 쪽(App)이 한다.
            throw .storeUnavailable
        }
    }
}

private enum StoreName {
    static let onDisk = "Persistence"
}
