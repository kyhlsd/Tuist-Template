//
//  ItemCacheWriterTests.swift
//  DataTests
//

@testable import Data
import Persistence
import Testing

@Suite("ItemCacheWriter")
struct ItemCacheWriterTests {
    private let older = [ItemCacheRecord(id: "old", title: "이전")]
    private let newer = [ItemCacheRecord(id: "new", title: "최근")]
    private let newest = [ItemCacheRecord(id: "newest", title: "가장 최근")]

    @Test("캐시가 앞선 쓰기를 끝내기 전에 비우면 앞선 쓰기가 끝난 뒤에도 비어 있다")
    func removeAll_whileEarlierWriteIsInsideCache_leavesCacheEmpty() async throws {
        let cache = ControlledItemCache(holdsFirstReplaceAll: true)
        let writer = ItemCacheWriter(cache: cache)
        let ticket = await writer.nextTicket()

        let write = Task { try await writer.replaceAll(with: older, ticket: ticket) }
        await cache.waitUntilReplaceAllHeld()
        let clear = Task { try await writer.removeAll() }
        await writer.waitUntilOperationsQueued(2)
        await cache.releaseHeldReplaceAll()
        try await write.value
        try await clear.value

        #expect(await cache.records.isEmpty)
    }

    @Test("늦게 시작한 요청의 쓰기가 실패하면 먼저 시작한 요청의 결과를 쓴다")
    func replaceAll_afterLaterWriteFailed_writesEarlierResult() async throws {
        let cache = ControlledItemCache(replaceAllFailures: 1)
        let writer = ItemCacheWriter(cache: cache)
        let earlier = await writer.nextTicket()
        let later = await writer.nextTicket()
        // 실패는 준비 단계다. 던지는 것 자체는 CachedItemRepository 테스트가 확인한다.
        try? await writer.replaceAll(with: newer, ticket: later)

        try await writer.replaceAll(with: older, ticket: earlier)

        #expect(await cache.records == older)
    }

    @Test("쓰는 중 비운 뒤 그 쓰기가 실패해도 비우기 전에 시작한 요청은 쓰지 않는다")
    func replaceAll_afterWriteFailedDuringClear_doesNotWriteRequestStartedBeforeClear() async throws {
        let cache = ControlledItemCache(replaceAllFailures: 1, holdsFirstReplaceAll: true)
        let writer = ItemCacheWriter(cache: cache)
        let earlier = await writer.nextTicket()
        let later = await writer.nextTicket()
        let failingWrite = Task { try await writer.replaceAll(with: newer, ticket: later) }
        await cache.waitUntilReplaceAllHeld()
        let clear = Task { try await writer.removeAll() }
        await writer.waitUntilOperationsQueued(2)
        await cache.releaseHeldReplaceAll()
        // 실패는 준비 단계다. 실패한 쓰기가 기준에서 빠진 뒤의 동작을 아래 쓰기로 확인한다.
        _ = await failingWrite.result
        try await clear.value

        try await writer.replaceAll(with: older, ticket: earlier)

        #expect(await cache.records.isEmpty)
    }

    @Test("늦게 시작한 두 요청의 쓰기가 연달아 실패하면 먼저 시작한 요청의 결과를 쓴다")
    func replaceAll_afterTwoLaterWritesFailed_writesEarliestResult() async throws {
        let cache = ControlledItemCache(replaceAllFailures: 2, holdsFirstReplaceAll: true)
        let writer = ItemCacheWriter(cache: cache)
        let first = await writer.nextTicket()
        let second = await writer.nextTicket()
        let third = await writer.nextTicket()
        let secondWrite = Task { try await writer.replaceAll(with: newer, ticket: second) }
        await cache.waitUntilReplaceAllHeld()
        let thirdWrite = Task { try await writer.replaceAll(with: newest, ticket: third) }
        await writer.waitUntilOperationsQueued(2)
        await cache.releaseHeldReplaceAll()
        // 두 실패는 준비 단계다. 실패 뒤의 기준을 아래 쓰기로 확인한다.
        _ = await secondWrite.result
        _ = await thirdWrite.result

        try await writer.replaceAll(with: older, ticket: first)

        #expect(await cache.records == older)
    }

    @Test("앞선 쓰기가 실패해도 줄에 선 더 늦은 쓰기가 성공하면 먼저 시작한 요청은 쓰지 않는다")
    func replaceAll_afterFailedWriteFollowedBySuccessfulLaterWrite_keepsLaterResult() async throws {
        let cache = ControlledItemCache(replaceAllFailures: 1, holdsFirstReplaceAll: true)
        let writer = ItemCacheWriter(cache: cache)
        let first = await writer.nextTicket()
        let second = await writer.nextTicket()
        let third = await writer.nextTicket()
        let secondWrite = Task { try await writer.replaceAll(with: newer, ticket: second) }
        await cache.waitUntilReplaceAllHeld()
        let thirdWrite = Task { try await writer.replaceAll(with: newest, ticket: third) }
        await writer.waitUntilOperationsQueued(2)
        await cache.releaseHeldReplaceAll()
        // 두 번째 쓰기의 실패는 준비 단계다.
        _ = await secondWrite.result
        try await thirdWrite.value

        try await writer.replaceAll(with: older, ticket: first)

        #expect(await cache.records == newest)
    }

    /// 조건이 빠지면 먼저 시작한 쓰기가 붙잡힌 쓰기 뒤에서 멈춘다. 멈춤이 실패로 드러나게 시간 제한을 둔다.
    @Test("늦게 시작한 요청이 쓰는 중이면 먼저 시작한 요청은 쓰지 않는다", .timeLimit(.minutes(1)))
    func replaceAll_whileLaterWriteInFlight_dropsEarlierResult() async throws {
        let cache = ControlledItemCache(holdsFirstReplaceAll: true)
        let writer = ItemCacheWriter(cache: cache)
        let earlier = await writer.nextTicket()
        let later = await writer.nextTicket()
        let laterWrite = Task { try await writer.replaceAll(with: newer, ticket: later) }
        await cache.waitUntilReplaceAllHeld()

        try await writer.replaceAll(with: older, ticket: earlier)
        await cache.releaseHeldReplaceAll()
        try await laterWrite.value

        #expect(await cache.records == newer)
    }
}
