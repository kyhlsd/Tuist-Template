//
//  InMemoryItemCache.swift
//  PersistenceTesting
//

import Persistence

/// 메모리에만 항목을 두는 `ItemCache`. 테스트에서 SwiftData 대신 쓴다.
///
/// 검증용으로 `load`, `replaceAll(with:)`, `removeAll()` 호출 횟수를 기록한다.
/// id 중복 정리는 하지 않고 받은 그대로 둔다(정리 규칙은 `SwiftDataItemCache` 테스트가 고정한다).
public actor InMemoryItemCache: ItemCache {
    public private(set) var records: [ItemCacheRecord]
    public private(set) var loadCount = 0
    public private(set) var replaceAllCount = 0
    public private(set) var removeAllCount = 0

    public init(records: [ItemCacheRecord] = []) {
        self.records = records
    }

    public func load() async throws(PersistenceError) -> [ItemCacheRecord] {
        loadCount += 1
        return records
    }

    public func replaceAll(with records: [ItemCacheRecord]) async throws(PersistenceError) {
        self.records = records
        replaceAllCount += 1
    }

    public func removeAll() async throws(PersistenceError) {
        records = []
        removeAllCount += 1
    }
}
