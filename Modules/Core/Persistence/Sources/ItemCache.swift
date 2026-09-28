//
//  ItemCache.swift
//  Persistence
//

/// 항목 오프라인 캐시.
///
/// 앱은 `SwiftDataItemCache` 를, 테스트는 `PersistenceTesting` 의 `InMemoryItemCache`, `FailingItemCache` 를 쓴다.
public protocol ItemCache: Sendable {
    /// 마지막으로 `replaceAll(with:)` 한 항목을 넣은 순서대로 돌려준다. 없으면 빈 배열.
    func load() async throws(PersistenceError) -> [ItemCacheRecord]
    /// 캐시를 `records` 로 통째로 바꾼다. id 가 겹치면 처음 나온 것만 남긴다.
    func replaceAll(with records: [ItemCacheRecord]) async throws(PersistenceError)
    /// 캐시를 비운다. 로그아웃처럼 이전 항목을 더 보여 주면 안 될 때 쓴다.
    func removeAll() async throws(PersistenceError)
}
