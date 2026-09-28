//
//  FailingItemCache.swift
//  PersistenceTesting
//

import Persistence

/// 읽기·쓰기·비우기가 늘 주어진 에러로 실패하는 `ItemCache`.
public struct FailingItemCache: ItemCache {
    private let error: PersistenceError

    public init(error: PersistenceError = .operationFailed) {
        self.error = error
    }

    public func load() async throws(PersistenceError) -> [ItemCacheRecord] {
        throw error
    }

    public func replaceAll(with _: [ItemCacheRecord]) async throws(PersistenceError) {
        throw error
    }

    public func removeAll() async throws(PersistenceError) {
        throw error
    }
}
