//
//  SwiftDataItemCache.swift
//  Persistence
//

import Foundation
import SwiftData

/// SwiftData 에 항목을 두는 `ItemCache`.
///
/// `@ModelActor` 는 만든 곳이 main actor 면 작업이 메인 스레드에서 돈다는 보고가 있어 쓰지 않는다.
/// 대신 첫 사용 때 자기 격리 안에서 `ModelContext` 를 만든다. `ModelContext` 와 모델 인스턴스는
/// `Sendable` 이 아니므로 이 actor 밖으로 내보내지 않는다.
public actor SwiftDataItemCache: ItemCache {
    private typealias ItemEntity = PersistenceSchemaV1.ItemEntity

    private let container: ModelContainer
    private var cachedContext: ModelContext?

    public init(database: LocalDatabase) {
        container = database.container
    }

    public func load() async throws(PersistenceError) -> [ItemCacheRecord] {
        let descriptor = FetchDescriptor<ItemEntity>(sortBy: [SortDescriptor(\.position)])
        do {
            return try context().fetch(descriptor).map { ItemCacheRecord(id: $0.id, title: $0.title) }
        } catch {
            // 원인은 PersistenceError 의 Equatable 을 위해 담지 않는다. 보고는 부르는 쪽(Data)이 한다.
            throw .operationFailed
        }
    }

    public func replaceAll(with records: [ItemCacheRecord]) async throws(PersistenceError) {
        let unique = records.removingDuplicateIDs()
        try commit { context in
            try Self.deleteAll(in: context)
            for (position, record) in unique.enumerated() {
                context.insert(ItemEntity(id: record.id, title: record.title, position: position))
            }
        }
    }

    public func removeAll() async throws(PersistenceError) {
        try commit { context in
            try Self.deleteAll(in: context)
        }
    }

    /// `changes` 를 적용하고 저장한다. 실패하면 되돌린다.
    private func commit(_ changes: (ModelContext) throws -> Void) throws(PersistenceError) {
        let context = context()
        do {
            try changes(context)
            try context.save()
        } catch {
            // 절반만 바뀐 상태가 다음 호출에 남지 않게 되돌린다. in-memory 저장소로는 save 실패를 일으킬 수 없어
            // 이 분기는 테스트하지 않는다. 원인은 담지 않고 보고는 부르는 쪽이 한다.
            context.rollback()
            throw .operationFailed
        }
    }

    private static func deleteAll(in context: ModelContext) throws {
        for entity in try context.fetch(FetchDescriptor<ItemEntity>()) {
            context.delete(entity)
        }
    }

    private func context() -> ModelContext {
        if let cachedContext {
            return cachedContext
        }
        let context = ModelContext(container)
        cachedContext = context
        return context
    }
}
