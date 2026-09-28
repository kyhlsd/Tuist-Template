//
//  ItemCacheRecordUniqueIDTests.swift
//  PersistenceTests
//

@testable import Persistence
import Testing

@Suite("[ItemCacheRecord].removingDuplicateIDs")
struct ItemCacheRecordUniqueIDTests {
    @Test("id 가 겹치면 처음 나온 것만 순서대로 남긴다")
    func removingDuplicateIDs_withDuplicates_keepsFirstOccurrencesInOrder() {
        let records = [
            ItemCacheRecord(id: "x", title: "X"),
            ItemCacheRecord(id: "y", title: "Y"),
            ItemCacheRecord(id: "x", title: "X again"),
        ]

        #expect(records.removingDuplicateIDs() == [
            ItemCacheRecord(id: "x", title: "X"),
            ItemCacheRecord(id: "y", title: "Y"),
        ])
    }
}
