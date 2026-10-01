//
//  HomeViewModel.swift
//  Home
//

import Domain
import HomeInterface
import Navigation
import Observation

/// 홈 화면 상태.
///
/// UseCase 와 Router 는 프로토콜로 주입받는다. 실제 구현은 App 이,
/// 스텁은 테스트·데모가 넣는다.
@MainActor
@Observable
public final class HomeViewModel {
    public enum State: Equatable {
        case idle
        case loading
        case loaded([Item])
        case failed(ItemError)
    }

    public private(set) var state: State = .idle
    /// 재시도를 요청한 횟수. 화면이 `.task(id:)` 의 id 로 써서, 바뀌면 `loadOnAppear()` 를 다시 부른다.
    public private(set) var retryRequest = 0

    @ObservationIgnored private let fetchItems: any FetchItemsUseCase
    @ObservationIgnored private let router: any Routing
    /// 마지막으로 시작한 `load()` 의 번호. 늦게 끝난 이전 호출이 상태를 덮어쓰지 않게 한다.
    @ObservationIgnored private var latestLoad = 0
    /// `loadOnAppear()` 가 마지막으로 처리한 `retryRequest`. 다르면 이번 호출은 재시도다.
    @ObservationIgnored private var handledRetryRequest = 0

    public init(fetchItems: any FetchItemsUseCase, router: any Routing) {
        self.fetchItems = fetchItems
        self.router = router
    }

    public func load() async {
        latestLoad += 1
        let load = latestLoad
        state = .loading
        do {
            let items = try await fetchItems.execute()
            guard load == latestLoad else { return }
            state = .loaded(items)
        } catch {
            // 취소돼도 바로 돌아오지 않는 호출(토큰 갱신 대기 등)이 있어서, 그사이 다시 시작한 호출이
            // 있으면 그 결과를 덮지 않는다.
            guard load == latestLoad else { return }
            // 화면을 벗어나 취소된 호출이면 다음 진입의 .task 가 다시 부르도록 되돌린다.
            state = Task.isCancelled ? .idle : .failed(error)
        }
    }

    /// 화면의 `.task(id: retryRequest)` 가 부른다. 진입할 때와 재시도를 요청했을 때 돈다.
    ///
    /// 상세에서 돌아올 때마다 다시 불러오지 않도록 아직 결과가 없을 때만 부른다. `.loading` 도 부른다.
    /// 화면을 벗어나 취소된 이전 호출이 아직 끝나지 않았을 수 있어서다. `.failed` 는 재시도를 요청했을 때만 부른다.
    public func loadOnAppear() async {
        // 처리했다고 표시하기 전에 비교한다. 순서가 바뀌면 재시도가 늘 재진입으로 보인다.
        let isRetry = retryRequest != handledRetryRequest
        handledRetryRequest = retryRequest
        guard isRetry || state == .idle || state == .loading else { return }
        await load()
    }

    /// 재시도를 요청한다. 실제 호출은 화면의 `.task(id:)` 가 `loadOnAppear()` 로 한다.
    ///
    /// 화면 수명에 묶인 `.task` 로 부르므로, 화면을 벗어나면 재시도도 취소되어 돌아왔을 때 요청이 겹치지 않는다.
    public func retry() {
        retryRequest += 1
    }

    public func select(_ item: Item) {
        router.push(HomeRoute.detail(id: item.id))
    }
}
