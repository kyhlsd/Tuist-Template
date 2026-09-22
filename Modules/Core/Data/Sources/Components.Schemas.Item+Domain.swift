//
//  Components.Schemas.Item+Domain.swift
//  Data
//

import Domain
import Networking

/// 생성 모델을 도메인 모델로 바꾼다. 명세가 바뀌어도 여기서 흡수하고 `Item` 은 그대로 둔다.
extension Components.Schemas.Item {
    func toDomain() -> Item {
        Item(id: id, title: title)
    }
}
