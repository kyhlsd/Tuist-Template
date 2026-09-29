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
    func load_useCaseSucceeds_becomesLoaded() async {
        let viewModel = makeViewModel(result: .success(Item.samples))

        await viewModel.load()

        #expect(viewModel.state == .loaded(Item.samples))
    }

    @Test("불러오기에 실패하면 도메인 에러를 담는다")
    func load_useCaseFails_becomesFailed() async {
        let viewModel = makeViewModel(result: .failure(.unavailable))

        await viewModel.load()

        #expect(viewModel.state == .failed(.unavailable))
    }

    @Test("불러오는 중에 취소되면 다음 진입에서 다시 부르도록 idle 로 돌아간다", .timeLimit(.minutes(1)))
    func load_cancelled_returnsToIdle() async {
        let useCase = SuspendingFetchItemsUseCase()
        let viewModel = HomeViewModel(fetchItems: useCase, router: SpyRouter())

        let task = Task { await viewModel.load() }
        for await _ in useCase.started {
            break
        }
        task.cancel()
        await task.value

        #expect(viewModel.state == .idle)
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
        HomeViewModel(fetchItems: StubFetchItemsUseCase(result: result), router: router)
    }
}

/// 취소될 때까지 끝나지 않다가, 취소되면 URLSession 처럼 `.unavailable` 을 던진다.
/// 호출이 시작되면 `started` 로 알린다.
private final class SuspendingFetchItemsUseCase: FetchItemsUseCase {
    let started: AsyncStream<Void>
    private let startedContinuation: AsyncStream<Void>.Continuation
    // continuation 을 붙들어 두어 스트림이 끝나지 않게 한다. 반복은 취소될 때에만 끝난다.
    private let neverYields: AsyncStream<Void>
    private let neverYieldsContinuation: AsyncStream<Void>.Continuation

    init() {
        (started, startedContinuation) = AsyncStream.makeStream()
        (neverYields, neverYieldsContinuation) = AsyncStream.makeStream()
    }

    func execute() async throws(ItemError) -> [Item] {
        startedContinuation.yield()
        for await _ in neverYields {}
        throw .unavailable
    }
}
