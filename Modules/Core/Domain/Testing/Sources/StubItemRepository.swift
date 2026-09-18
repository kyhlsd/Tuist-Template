//
//  StubItemRepository.swift
//  DomainTesting
//

import Domain

/// 정해진 결과를 돌려주는 `ItemRepository`.
///
/// 테스트와 데모 앱이 함께 쓴다. 모듈마다 스텁을 새로 만들지 않는다.
public struct StubItemRepository: ItemRepository {
    private let result: Result<[Item], ItemError>

    public init(result: Result<[Item], ItemError>) {
        self.result = result
    }

    public func fetchItems() async throws(ItemError) -> [Item] {
        try result.get()
    }
}
