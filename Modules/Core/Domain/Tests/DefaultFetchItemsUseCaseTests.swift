//
//  DefaultFetchItemsUseCaseTests.swift
//  DomainTests
//

import Domain
import DomainTesting
import Testing

@Suite("DefaultFetchItemsUseCase")
struct DefaultFetchItemsUseCaseTests {
    @Test("제목의 사람 기준 순서로 정렬한다")
    func execute_unsortedItems_sortsByTitle() async throws {
        let useCase = makeUseCase(items: [
            Item(id: "a", title: "항목 10"),
            Item(id: "b", title: "항목 2"),
            Item(id: "c", title: "항목 1"),
        ])

        let items = try await useCase.execute()

        #expect(items.map(\.id) == ["c", "b", "a"])
    }

    @Test("제목이 비었거나 공백뿐인 항목은 뺀다")
    func execute_blankTitles_excludesThem() async throws {
        let useCase = makeUseCase(items: [
            Item(id: "a", title: "항목"),
            Item(id: "b", title: ""),
            Item(id: "c", title: " \n"),
        ])

        let items = try await useCase.execute()

        #expect(items.map(\.id) == ["a"])
    }

    @Test("저장소가 실패하면 같은 도메인 에러를 던진다")
    func execute_repositoryFails_rethrowsError() async {
        let useCase = DefaultFetchItemsUseCase(repository: StubItemRepository(result: .failure(.unavailable)))

        await #expect(throws: ItemError.unavailable) {
            try await useCase.execute()
        }
    }

    private func makeUseCase(items: [Item]) -> DefaultFetchItemsUseCase {
        DefaultFetchItemsUseCase(repository: StubItemRepository(result: .success(items)))
    }
}
