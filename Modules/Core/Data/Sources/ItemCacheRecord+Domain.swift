//
//  ItemCacheRecord+Domain.swift
//  Data
//

import Domain
import Persistence

/// 캐시 레코드와 도메인 모델을 오간다. Persistence 는 Domain 을 모르므로 변환은 여기 한 곳에 둔다.
extension ItemCacheRecord {
    init(item: Item) {
        self.init(id: item.id, title: item.title)
    }

    func toDomain() -> Item {
        Item(id: id, title: title)
    }
}
