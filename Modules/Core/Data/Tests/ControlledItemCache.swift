//
//  ControlledItemCache.swift
//  DataTests
//

import Persistence

/// 쓰기를 붙잡아 두거나 처음 몇 번 실패시킬 수 있는 `ItemCache`.
///
/// `holdsFirstReplaceAll` 이면 첫 `replaceAll` 만 `releaseHeldReplaceAll()` 까지 기다린 뒤 쓴다.
/// 뒤이은 호출은 붙잡지 않는다. 회귀로 쓰지 말아야 할 호출이 도착해도 테스트가 멈추지 않고 실패하게 하기 위해서다.
actor ControlledItemCache: ItemCache {
    private(set) var records: [ItemCacheRecord] = []
    private var replaceAllFailures: Int
    private var holdsNextReplaceAll: Bool
    private var heldReplaceAll: CheckedContinuation<Void, Never>?
    private var holdWaiter: CheckedContinuation<Void, Never>?

    init(replaceAllFailures: Int = 0, holdsFirstReplaceAll: Bool = false) {
        self.replaceAllFailures = replaceAllFailures
        holdsNextReplaceAll = holdsFirstReplaceAll
    }

    func load() async throws(PersistenceError) -> [ItemCacheRecord] {
        records
    }

    func replaceAll(with records: [ItemCacheRecord]) async throws(PersistenceError) {
        if holdsNextReplaceAll {
            holdsNextReplaceAll = false
            await withCheckedContinuation { continuation in
                heldReplaceAll = continuation
                holdWaiter?.resume()
                holdWaiter = nil
            }
        }
        if replaceAllFailures > 0 {
            replaceAllFailures -= 1
            throw .operationFailed
        }
        self.records = records
    }

    func removeAll() async throws(PersistenceError) {
        records = []
    }

    /// `replaceAll` 이 붙잡힐 때까지 기다린다.
    func waitUntilReplaceAllHeld() async {
        guard heldReplaceAll == nil else {
            return
        }
        await withCheckedContinuation { continuation in
            holdWaiter = continuation
        }
    }

    /// 붙잡힌 `replaceAll` 을 이어 가게 한다.
    func releaseHeldReplaceAll() {
        heldReplaceAll?.resume()
        heldReplaceAll = nil
    }
}
