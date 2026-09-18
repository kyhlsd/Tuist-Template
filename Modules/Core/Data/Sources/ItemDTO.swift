//
//  ItemDTO.swift
//  Data
//

import Domain

/// 서버 응답의 항목 표현. 응답 형식이 바뀌어도 여기서 흡수하고 `Item` 은 그대로 둔다.
struct ItemDTO: Decodable, Sendable {
    let id: String
    let title: String

    func toDomain() -> Item {
        Item(id: id, title: title)
    }
}
