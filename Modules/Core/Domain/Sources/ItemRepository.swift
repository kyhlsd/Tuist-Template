//
//  ItemRepository.swift
//  Domain
//

/// 항목 저장소.
///
/// Domain 은 프로토콜만 선언한다. 구현은 Data 의 `RemoteItemRepository`,
/// 테스트·데모용 스텁은 DomainTesting 의 `StubItemRepository` 다.
/// 어떤 구현을 쓸지는 App 이 정한다.
public protocol ItemRepository: Sendable {
    func fetchItems() async throws(ItemError) -> [Item]
}
