//
//  PersistenceSchemaV1+ItemEntity.swift
//  Persistence
//

import SwiftData

extension PersistenceSchemaV1 {
    /// 캐시된 항목 한 개. `Sendable` 이 아니므로 `SwiftDataItemCache` 밖으로 내보내지 않고
    /// `ItemCacheRecord` 로 바꿔 돌려준다.
    @Model
    final class ItemEntity {
        /// `#Unique` 는 iOS 18 부터라 속성 단위 제약을 쓴다.
        @Attribute(.unique) var id: String
        var title: String
        /// 원격이 준 순서. 읽을 때 이 순서로 정렬한다.
        var position: Int

        init(id: String, title: String, position: Int) {
            self.id = id
            self.title = title
            self.position = position
        }
    }
}
