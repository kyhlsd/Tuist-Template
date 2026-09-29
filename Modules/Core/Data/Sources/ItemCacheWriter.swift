//
//  ItemCacheWriter.swift
//  Data
//

import Persistence

/// 캐시 쓰기를 원격 요청이 시작된 순서로 줄 세운다.
///
/// 요청이 겹치면 먼저 시작한 요청이 나중에 끝날 수 있다. 그 결과가 더 최근 결과를 덮어쓰지 않게,
/// 쓰기에 성공했거나 쓰는 중인 요청보다 먼저 시작한 요청의 쓰기는 버린다. 실패한 쓰기는 기준에서 빠진다.
/// 비우기는 따로 기준을 두어, 비운 뒤에 끝난 이전 요청(예: 로그아웃 전에 시작한 요청)이 캐시를 되살리지 않게 한다.
///
/// 쓸지 말지는 호출한 시점(첫 `await` 전)에 정하고, 실제 캐시 호출은 그 순서대로 하나씩 실행한다.
/// 판단과 캐시 호출 사이에 actor 재진입이 있어도, 캐시 actor 가 우선순위로 작업 순서를 바꿔도 판단한 순서대로 반영된다.
/// 이 순서는 쓰기·비우기에만 적용한다. 캐시 읽기(`CachedItemRepository` 의 `cache.load()`)는 줄을 거치지 않으므로
/// 비우기와 겹친 읽기는 비우기 전 항목을 볼 수 있다.
///
/// 순서는 이 인스턴스를 거친 쓰기끼리만 맞춘다. 같은 캐시를 여러 `CachedItemRepository` 가 쓰면 맞추지 않는다.
actor ItemCacheWriter {
    private let cache: any ItemCache
    /// 마지막으로 나눠 준 요청 번호.
    private var lastIssued = 0
    /// 쓰기가 성공한 가장 늦게 시작한 요청 번호.
    private var lastSucceeded = 0
    /// 줄에 세웠고 아직 끝나지 않은 쓰기의 요청 번호.
    private var inFlightWrites: Set<Int> = []
    /// 마지막 비우기 때까지 나눠 준 요청 번호. 이 번호 이하의 요청은 쓰지 않는다. 되돌리지 않는다.
    private var clearedThrough = 0
    /// 마지막으로 줄 세운 캐시 호출. 다음 호출은 이것이 끝난 뒤에 실행한다.
    private var lastOperation: Task<PersistenceError?, Never>?
    /// 줄 세운 캐시 호출 수. 테스트 동기화 지점(`waitUntilOperationsQueued(_:)`)이 쓴다.
    private var queuedOperations = 0
    private var queueWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(cache: any ItemCache) {
        self.cache = cache
    }

    /// 원격 요청을 시작하기 전에 부른다. 받은 번호를 `replaceAll(with:ticket:)` 에 넘긴다.
    func nextTicket() -> Int {
        lastIssued += 1
        return lastIssued
    }

    /// `ticket` 보다 늦게 시작한 요청이 쓰기에 성공했거나 쓰는 중이거나, 그 뒤에 캐시를 비웠으면 쓰지 않는다.
    ///
    /// 기준은 성공한 번호와 진행 중인 번호로 매번 계산한다. 실패한 쓰기는 끝나는 즉시 기준에서 빠지므로,
    /// 쓰기가 연달아 실패해도 뒤이어 끝나는 먼저 시작한 요청의 결과는 쓸 수 있다.
    /// 실패한 쓰기가 진행되는 동안 도착해 이미 버려진 요청은 되살리지 않는다.
    func replaceAll(with records: [ItemCacheRecord], ticket: Int) async throws(PersistenceError) {
        guard ticket > max(lastSucceeded, inFlightWrites.max() ?? 0, clearedThrough) else {
            return
        }
        inFlightWrites.insert(ticket)
        defer { inFlightWrites.remove(ticket) }
        try await serialized { cache throws(PersistenceError) in
            try await cache.replaceAll(with: records)
        }
        lastSucceeded = max(lastSucceeded, ticket)
    }

    /// 캐시를 비운다. 지금까지 시작한 요청의 결과는 이후에 끝나도 쓰지 않는다.
    func removeAll() async throws(PersistenceError) {
        clearedThrough = lastIssued
        try await serialized { cache throws(PersistenceError) in
            try await cache.removeAll()
        }
    }

    /// 캐시 호출을 부른 순서대로 하나씩 실행한다. 앞선 호출이 실패해도 다음 호출은 실행한다.
    ///
    /// `AuthSession` 의 저장소 접근 직렬화와 같은 방식이다. 호출은 구조화되지 않은 Task 에서 돌므로
    /// 부른 쪽이 취소돼도 캐시 호출까지 취소가 전달되지 않는다. 캐시 구현이 취소를 존중하게 되면 여기를 함께 고친다.
    private func serialized(
        _ operation: @escaping @Sendable (any ItemCache) async throws(PersistenceError) -> Void
    ) async throws(PersistenceError) {
        let previous = lastOperation
        let cache = cache
        let task = Task<PersistenceError?, Never> {
            _ = await previous?.value
            do throws(PersistenceError) {
                try await operation(cache)
                return nil
            } catch {
                return error
            }
        }
        lastOperation = task
        queuedOperations += 1
        resumeQueueWaiters()
        if let error = await task.value {
            throw error
        }
    }

    private func resumeQueueWaiters() {
        let ready = queueWaiters.filter { queuedOperations >= $0.count }
        queueWaiters.removeAll { queuedOperations >= $0.count }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }
}

// MARK: - 테스트 동기화 지점

extension ItemCacheWriter {
    /// 줄 세운 캐시 호출이 `count` 개가 될 때까지 기다린다. 앞선 호출이 끝나지 않아도 돌아온다.
    ///
    /// 앞선 쓰기를 붙잡아 둔 채 비우기가 줄에 들어갔는지 sleep 없이 확인하려고 둔다(`@testable import` 로만 쓴다).
    func waitUntilOperationsQueued(_ count: Int) async {
        guard queuedOperations < count else {
            return
        }
        await withCheckedContinuation { continuation in
            queueWaiters.append((count, continuation))
        }
    }
}
