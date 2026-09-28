//
//  ItemCacheWriter.swift
//  Data
//

import Persistence

/// 캐시 쓰기를 원격 요청이 시작된 순서로 줄 세운다.
///
/// 요청이 겹치면 먼저 시작한 요청이 나중에 끝날 수 있다. 그 결과가 더 최근 결과를 덮어쓰지 않게,
/// 이미 반영한 요청보다 먼저 시작한 요청의 쓰기는 버린다. 비우기도 같은 기준을 써서, 비운 뒤에 끝난
/// 이전 요청(예: 로그아웃 전에 시작한 요청)이 캐시를 되살리지 않게 한다.
///
/// 순서는 이 인스턴스를 거친 쓰기끼리만 맞춘다. 같은 캐시를 여러 `CachedItemRepository` 가 쓰면 맞추지 않는다.
actor ItemCacheWriter {
    private let cache: any ItemCache
    /// 마지막으로 나눠 준 요청 번호.
    private var lastIssued = 0
    /// 캐시에 반영한(또는 비우기로 무효가 된) 마지막 요청 번호.
    private var lastApplied = 0

    init(cache: any ItemCache) {
        self.cache = cache
    }

    /// 원격 요청을 시작하기 전에 부른다. 받은 번호를 `replaceAll(with:ticket:)` 에 넘긴다.
    func nextTicket() -> Int {
        lastIssued += 1
        return lastIssued
    }

    /// `ticket` 보다 늦게 시작한 요청이 이미 반영됐거나 그 뒤에 캐시를 비웠으면 쓰지 않는다.
    func replaceAll(with records: [ItemCacheRecord], ticket: Int) async throws(PersistenceError) {
        guard ticket > lastApplied else {
            return
        }
        // 기다리기 전에 올려 둔다. 기다리는 동안 들어온 이전 요청의 쓰기도 버려진다.
        lastApplied = ticket
        try await cache.replaceAll(with: records)
    }

    /// 캐시를 비운다. 지금까지 시작한 요청의 결과는 이후에 끝나도 쓰지 않는다.
    func removeAll() async throws(PersistenceError) {
        lastApplied = lastIssued
        try await cache.removeAll()
    }
}
