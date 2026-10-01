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

    @Test("취소된 이전 호출이 늦게 끝나도 나중에 시작한 호출의 결과를 덮지 않는다", .timeLimit(.minutes(1)))
    func load_cancelledLoadFinishesLate_keepsLatestResult() async {
        let useCase = GatedFetchItemsUseCase()
        let viewModel = HomeViewModel(fetchItems: useCase, router: SpyRouter())
        var started = useCase.started.makeAsyncIterator()

        let first = Task { await viewModel.load() }
        await started.next()
        first.cancel()
        let second = Task { await viewModel.load() }
        await started.next()
        await useCase.finish(call: 1, with: .success(Item.samples))
        await second.value
        await useCase.finish(call: 0, with: .failure(.unavailable))
        await first.value

        #expect(viewModel.state == .loaded(Item.samples))
    }

    @Test("취소된 이전 호출이 늦게 성공해도 나중에 시작한 호출의 실패를 덮지 않는다", .timeLimit(.minutes(1)))
    func load_cancelledLoadSucceedsLate_keepsLatestFailure() async {
        let useCase = GatedFetchItemsUseCase()
        let viewModel = HomeViewModel(fetchItems: useCase, router: SpyRouter())
        var started = useCase.started.makeAsyncIterator()

        let first = Task { await viewModel.load() }
        await started.next()
        first.cancel()
        let second = Task { await viewModel.load() }
        await started.next()
        await useCase.finish(call: 1, with: .failure(.unavailable))
        await second.value
        await useCase.finish(call: 0, with: .success(Item.samples))
        await first.value

        #expect(viewModel.state == .failed(.unavailable))
    }

    @Test("불러오는 중 화면을 벗어났다 돌아오면 다시 불러온다", .timeLimit(.minutes(1)))
    func loadOnAppear_loadingAfterCancel_loadsAgain() async {
        let useCase = GatedFetchItemsUseCase(laterResult: .success(Item.samples))
        let viewModel = HomeViewModel(fetchItems: useCase, router: SpyRouter())
        var started = useCase.started.makeAsyncIterator()

        let first = Task { await viewModel.loadOnAppear() }
        await started.next()
        first.cancel()
        // 취소된 첫 호출이 아직 끝나지 않아 상태는 `.loading` 이다. 두 번째 호출은 게이트에 걸리지 않으므로
        // 끝까지 기다릴 수 있다. 다시 불러오지 않으면 멈추지 않고 `.loading` 으로 남아 바로 실패한다.
        await viewModel.loadOnAppear()

        #expect(viewModel.state == .loaded(Item.samples))
        // 단언이 실패해도 첫 호출을 끝내 continuation 을 남기지 않는다.
        await useCase.finish(call: 0, with: .failure(.unavailable))
        await first.value
        #expect(viewModel.state == .loaded(Item.samples))
    }

    @Test("실패한 뒤 재시도 없이 다시 진입하면 불러오지 않고 실패를 그대로 둔다")
    func loadOnAppear_failedWithoutRetry_keepsFailure() async {
        let viewModel = HomeViewModel(
            fetchItems: SequencedFetchItemsUseCase(results: [.failure(.unavailable), .success(Item.samples)]),
            router: SpyRouter()
        )
        await viewModel.loadOnAppear()

        await viewModel.loadOnAppear()

        #expect(viewModel.state == .failed(.unavailable))
    }

    @Test("실패한 뒤 재시도를 요청하면 다시 불러온다")
    func loadOnAppear_failedWithRetry_loads() async {
        let viewModel = HomeViewModel(
            fetchItems: SequencedFetchItemsUseCase(results: [.failure(.unavailable), .success(Item.samples)]),
            router: SpyRouter()
        )
        await viewModel.loadOnAppear()

        viewModel.retry()
        await viewModel.loadOnAppear()

        #expect(viewModel.state == .loaded(Item.samples))
    }

    @Test("재시도 요청 하나는 한 번만 불러온다")
    func loadOnAppear_retryHandled_doesNotLoadAgainOnNextAppear() async {
        let viewModel = HomeViewModel(
            fetchItems: SequencedFetchItemsUseCase(
                results: [.failure(.unavailable), .failure(.unavailable), .success(Item.samples)]
            ),
            router: SpyRouter()
        )
        await viewModel.loadOnAppear()
        viewModel.retry()
        await viewModel.loadOnAppear()

        await viewModel.loadOnAppear()

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

/// 취소를 무시하고, 테스트가 `finish(call:with:)` 로 끝낼 때까지 기다린다.
/// 취소돼도 바로 돌아오지 않는 호출(토큰 갱신을 기다리는 요청 등)을 흉내 낸다.
/// 호출이 시작되면 `started` 로 알린다.
private actor GatedFetchItemsUseCase: FetchItemsUseCase {
    nonisolated let started: AsyncStream<Void>
    private nonisolated let startedContinuation: AsyncStream<Void>.Continuation
    private var calls: [CheckedContinuation<Result<[Item], ItemError>, Never>] = []
    private let laterResult: Result<[Item], ItemError>?

    /// - Parameter laterResult: 주면 첫 호출만 게이트에 걸고, 그 뒤 호출은 이 결과를 바로 돌려준다.
    ///   없으면 모든 호출을 게이트에 건다.
    init(laterResult: Result<[Item], ItemError>? = nil) {
        (started, startedContinuation) = AsyncStream.makeStream()
        self.laterResult = laterResult
    }

    func execute() async throws(ItemError) -> [Item] {
        if let laterResult, !calls.isEmpty {
            return try laterResult.get()
        }
        let result = await withCheckedContinuation { continuation in
            calls.append(continuation)
            startedContinuation.yield()
        }
        return try result.get()
    }

    func finish(call index: Int, with result: Result<[Item], ItemError>) {
        calls[index].resume(returning: result)
    }
}

/// 정해진 결과를 호출 순서대로 돌려준다. 결과보다 많이 부르면 이슈를 남기고 실패를 던진다.
private actor SequencedFetchItemsUseCase: FetchItemsUseCase {
    private var results: [Result<[Item], ItemError>]

    init(results: [Result<[Item], ItemError>]) {
        self.results = results
    }

    func execute() async throws(ItemError) -> [Item] {
        guard !results.isEmpty else {
            // 프로세스를 죽이지 않고 이 테스트만 실패시킨다(다른 테스트 대역과 같은 방식).
            Issue.record("준비한 결과보다 많이 불렀습니다.")
            throw .unavailable
        }
        return try results.removeFirst().get()
    }
}
