//
//  AppContainerItemRepositoryTests.swift
//  TuistAppTests
//

import Domain
import DomainTesting
import Testing
@testable import TuistApp

/// UI 테스트 인자로 항목 저장소를 바꾸는 분기를 고정한다. 테스트는 Debug 로 돌므로 DEBUG 분기를 확인한다.
@MainActor
@Suite("AppContainer 항목 저장소 선택")
struct AppContainerItemRepositoryTests {
    private let defaultItems = [Item(id: "default", title: "기본")]

    @Test("UI 테스트 인자가 있으면 고정 항목을 돌려준다")
    func makeItemRepository_withStubArgument_returnsStubItems() async throws {
        let repository = AppContainer.makeItemRepository(
            default: StubItemRepository(result: .success(defaultItems)),
            arguments: [Argument.executable, UITestLaunchArgument.stubItems]
        )

        let items = try await repository.fetchItems()

        #expect(items.map(\.title) == [UITestLaunchArgument.stubItemTitle])
    }

    @Test("UI 테스트 인자가 없으면 넘긴 저장소를 쓴다")
    func makeItemRepository_withoutStubArgument_returnsDefault() async throws {
        let repository = AppContainer.makeItemRepository(
            default: StubItemRepository(result: .success(defaultItems)),
            arguments: [Argument.executable]
        )

        let items = try await repository.fetchItems()

        #expect(items == defaultItems)
    }
}

private enum Argument {
    static let executable = "/path/to/TuistApp"
}
