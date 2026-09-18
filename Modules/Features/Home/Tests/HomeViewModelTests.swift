//
//  HomeViewModelTests.swift
//  HomeTests
//

import Domain
import DomainTesting
import Home
import HomeInterface
import NavigationTesting
import Testing

@MainActor
@Suite("HomeViewModel")
struct HomeViewModelTests {
    @Test("불러오기에 성공하면 항목을 보여준다")
    func load_repositorySucceeds_becomesLoaded() async {
        let viewModel = makeViewModel(result: .success(Item.samples))

        await viewModel.load()

        #expect(viewModel.state == .loaded(Item.samples))
    }

    @Test("불러오기에 실패하면 도메인 에러를 담는다")
    func load_repositoryFails_becomesFailed() async {
        let viewModel = makeViewModel(result: .failure(.unavailable))

        await viewModel.load()

        #expect(viewModel.state == .failed(.unavailable))
    }

    @Test("항목을 고르면 그 항목의 상세로 이동을 요청한다")
    func select_item_pushesDetailRoute() throws {
        let router = SpyRouter()
        let viewModel = makeViewModel(result: .success(Item.samples), router: router)
        let item = try #require(Item.samples.first)

        viewModel.select(item)

        #expect(router.pushedRoutes == [HomeRoute.detail(id: item.id)])
    }

    private func makeViewModel(
        result: Result<[Item], ItemError>,
        router: SpyRouter = SpyRouter()
    ) -> HomeViewModel {
        HomeViewModel(repository: StubItemRepository(result: result), router: router)
    }
}
