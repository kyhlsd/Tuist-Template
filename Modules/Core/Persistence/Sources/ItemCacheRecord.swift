//
//  ItemCacheRecord.swift
//  Persistence
//

/// 캐시에 넣고 꺼내는 항목. Persistence 는 Domain 을 모르므로 `Item` 과의 변환은 Data 가 맡는다.
public struct ItemCacheRecord: Sendable, Equatable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}
