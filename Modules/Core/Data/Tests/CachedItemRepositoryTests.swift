//
//  CachedItemRepositoryTests.swift
//  DataTests
//

import Data
import DiagnosticsTesting
import Domain
import DomainTesting
import Persistence
import PersistenceTesting
import Testing

@Suite("CachedItemRepository")
struct CachedItemRepositoryTests {
    private let reporter = SpyDiagnosticReporter()
    private let cachedRecords = [
        ItemCacheRecord(id: "9", title: "캐시된 항목"),
    ]
    private let cachedItems = [
        Item(id: "9", title: "캐시된 항목"),
    ]

    @Test("원격이 성공하면 원격 결과를 돌려준다")
    func fetchItems_remoteSucceeds_returnsRemoteItems() async throws {
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .success(Item.samples)),
            cache: InMemoryItemCache(records: cachedRecords),
            reporter: reporter
        )

        #expect(try await repository.fetchItems() == Item.samples)
    }

    @Test("원격이 성공하면 캐시를 원격 결과로 한 번 교체한다")
    func fetchItems_remoteSucceeds_replacesCacheOnce() async throws {
        let cache = InMemoryItemCache(records: cachedRecords)
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .success(Item.samples)),
            cache: cache,
            reporter: reporter
        )

        _ = try await repository.fetchItems()

        #expect(await cache.records.map { Item(id: $0.id, title: $0.title) } == Item.samples)
        #expect(await cache.replaceAllCount == 1)
    }

    @Test("원격이 unavailable 이고 캐시가 있으면 캐시 항목을 돌려준다")
    func fetchItems_remoteUnavailableWithCache_returnsCachedItems() async throws {
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .failure(.unavailable)),
            cache: InMemoryItemCache(records: cachedRecords),
            reporter: reporter
        )

        #expect(try await repository.fetchItems() == cachedItems)
    }

    @Test("원격이 unavailable 이고 캐시가 비어 있으면 unavailable 을 던진다")
    func fetchItems_remoteUnavailableWithEmptyCache_throwsUnavailable() async {
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .failure(.unavailable)),
            cache: InMemoryItemCache(),
            reporter: reporter
        )

        await #expect(throws: ItemError.unavailable) {
            try await repository.fetchItems()
        }
    }

    @Test("원격이 invalidData 면 캐시가 있어도 invalidData 를 던진다")
    func fetchItems_remoteInvalidDataWithCache_throwsInvalidData() async {
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .failure(.invalidData)),
            cache: InMemoryItemCache(records: cachedRecords),
            reporter: reporter
        )

        await #expect(throws: ItemError.invalidData) {
            try await repository.fetchItems()
        }
    }

    @Test("원격이 성공하고 캐시 쓰기가 실패하면 원격 결과를 돌려주고 한 번 보고한다")
    func fetchItems_remoteSucceedsCacheWriteFails_returnsRemoteItemsAndReportsOnce() async throws {
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .success(Item.samples)),
            cache: FailingItemCache(),
            reporter: reporter
        )

        let items = try await repository.fetchItems()

        #expect(items == Item.samples)
        #expect(reporter.reported.map(\.summary) == ["operationFailed"])
    }

    @Test("원격이 unavailable 이고 캐시 읽기가 실패하면 unavailable 을 던지고 한 번 보고한다")
    func fetchItems_remoteUnavailableCacheReadFails_throwsUnavailableAndReportsOnce() async {
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .failure(.unavailable)),
            cache: FailingItemCache(),
            reporter: reporter
        )

        await #expect(throws: ItemError.unavailable) {
            try await repository.fetchItems()
        }
        #expect(reporter.reported.map(\.summary) == ["operationFailed"])
    }

    @Test("취소된 호출은 캐시가 있어도 unavailable 을 던진다")
    func fetchItems_cancelledWhileRemoteUnavailable_throwsUnavailableWithoutCache() async {
        let cache = InMemoryItemCache(records: cachedRecords)
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .failure(.unavailable)),
            cache: cache,
            reporter: reporter
        )

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await repository.fetchItems()
        }

        await #expect(throws: ItemError.unavailable) {
            try await task.value
        }
        #expect(await cache.loadCount == 0)
    }

    @Test("먼저 시작한 요청이 나중에 끝나도 늦게 시작한 요청의 결과가 캐시에 남는다")
    func fetchItems_earlierRequestFinishesLast_keepsLaterResultInCache() async throws {
        let remote = HeldItemRepository()
        let cache = InMemoryItemCache()
        let repository = CachedItemRepository(remote: remote, cache: cache, reporter: reporter)
        let older = [Item(id: "old", title: "이전")]
        let newer = [Item(id: "new", title: "최근")]

        let earlier = Task { try await repository.fetchItems() }
        await remote.waitForCalls(1)
        let later = Task { try await repository.fetchItems() }
        await remote.waitForCalls(2)
        await remote.finishCall(1, with: newer)
        _ = try await later.value
        await remote.finishCall(0, with: older)
        _ = try await earlier.value

        #expect(await cache.records == [ItemCacheRecord(id: "new", title: "최근")])
    }

    @Test("clearCache 는 캐시를 비운다")
    func clearCache_removesCachedRecords() async {
        let cache = InMemoryItemCache(records: cachedRecords)
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .success(Item.samples)),
            cache: cache,
            reporter: reporter
        )

        await repository.clearCache()

        #expect(await cache.records.isEmpty)
    }

    @Test("clearCache 전에 시작한 요청은 끝나도 캐시에 쓰지 않는다")
    func clearCache_whileRequestInFlight_doesNotWriteStaleResult() async throws {
        let remote = HeldItemRepository()
        let cache = InMemoryItemCache()
        let repository = CachedItemRepository(remote: remote, cache: cache, reporter: reporter)

        let inFlight = Task { try await repository.fetchItems() }
        await remote.waitForCalls(1)
        await repository.clearCache()
        await remote.finishCall(0, with: Item.samples)
        _ = try await inFlight.value

        #expect(await cache.records.isEmpty)
    }

    @Test("clearCache 가 실패하면 한 번 보고한다")
    func clearCache_whenCacheFails_reportsOnce() async {
        let repository = CachedItemRepository(
            remote: StubItemRepository(result: .success(Item.samples)),
            cache: FailingItemCache(),
            reporter: reporter
        )

        await repository.clearCache()

        #expect(reporter.reported.map(\.summary) == ["operationFailed"])
    }
}
