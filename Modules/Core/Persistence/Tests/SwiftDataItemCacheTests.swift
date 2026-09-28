//
//  SwiftDataItemCacheTests.swift
//  PersistenceTests
//

import Persistence
import Testing

@Suite("SwiftDataItemCache")
struct SwiftDataItemCacheTests {
    private let first = [
        ItemCacheRecord(id: "b", title: "Second"),
        ItemCacheRecord(id: "a", title: "First"),
        ItemCacheRecord(id: "c", title: "Third"),
    ]
    private let second = [
        ItemCacheRecord(id: "c", title: "Third updated"),
        ItemCacheRecord(id: "d", title: "Fourth"),
    ]

    @Test("비어 있는 캐시를 읽으면 빈 배열이다")
    func load_whenEmpty_returnsEmpty() async throws {
        let cache = try SwiftDataItemCache(database: LocalDatabase(location: .inMemory))

        #expect(try await cache.load().isEmpty)
    }

    @Test("replaceAll 한 뒤 읽으면 넣은 순서 그대로다")
    func load_afterReplaceAll_returnsRecordsInInsertedOrder() async throws {
        let cache = try SwiftDataItemCache(database: LocalDatabase(location: .inMemory))

        try await cache.replaceAll(with: first)

        #expect(try await cache.load() == first)
    }

    @Test("두 번 replaceAll 하면 두 번째 목록만 남는다")
    func load_afterReplacingTwice_returnsOnlySecondRecords() async throws {
        let cache = try SwiftDataItemCache(database: LocalDatabase(location: .inMemory))
        try await cache.replaceAll(with: first)

        try await cache.replaceAll(with: second)

        #expect(try await cache.load() == second)
    }

    @Test("removeAll 한 뒤 읽으면 빈 배열이다")
    func load_afterRemoveAll_returnsEmpty() async throws {
        let cache = try SwiftDataItemCache(database: LocalDatabase(location: .inMemory))
        try await cache.replaceAll(with: first)

        try await cache.removeAll()

        #expect(try await cache.load().isEmpty)
    }

    @Test("id 가 겹치면 처음 나온 것만 넣은 순서대로 남긴다")
    func load_afterReplacingWithDuplicateIDs_keepsFirstOccurrencesInOrder() async throws {
        let cache = try SwiftDataItemCache(database: LocalDatabase(location: .inMemory))
        let duplicated = [
            ItemCacheRecord(id: "x", title: "X"),
            ItemCacheRecord(id: "y", title: "Y"),
            ItemCacheRecord(id: "x", title: "X again"),
        ]

        try await cache.replaceAll(with: duplicated)

        #expect(try await cache.load() == [
            ItemCacheRecord(id: "x", title: "X"),
            ItemCacheRecord(id: "y", title: "Y"),
        ])
    }

    @Test("같은 LocalDatabase 를 공유하는 다른 캐시가 쓴 것을 읽는다")
    func load_whenAnotherCacheWroteToSharedDatabase_returnsWrittenRecords() async throws {
        let database = try LocalDatabase(location: .inMemory)
        let writer = SwiftDataItemCache(database: database)
        let reader = SwiftDataItemCache(database: database)

        try await writer.replaceAll(with: first)

        #expect(try await reader.load() == first)
    }
}
