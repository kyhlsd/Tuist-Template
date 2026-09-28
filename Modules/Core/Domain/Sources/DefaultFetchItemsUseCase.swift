//
//  DefaultFetchItemsUseCase.swift
//  Domain
//

import Foundation

/// `FetchItemsUseCase` 의 기본 구현.
///
/// 예시 규칙: 제목이 빈 항목은 보여주지 않고, 제목의 사람 기준 순서(숫자는 크기대로)로 정렬한다.
/// 서버가 어떤 순서로 주든 화면의 순서는 여기서 정한다.
public struct DefaultFetchItemsUseCase: FetchItemsUseCase {
    private let repository: any ItemRepository

    public init(repository: any ItemRepository) {
        self.repository = repository
    }

    public func execute() async throws(ItemError) -> [Item] {
        try await repository.fetchItems()
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
