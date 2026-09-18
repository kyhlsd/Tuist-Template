//
//  Item+Fixtures.swift
//  DomainTesting
//

import Domain

public extension Item {
    /// 테스트·데모용 표본.
    static let samples: [Item] = [
        Item(id: "1", title: "첫 번째 항목"),
        Item(id: "2", title: "두 번째 항목"),
        Item(id: "3", title: "세 번째 항목"),
    ]
}
