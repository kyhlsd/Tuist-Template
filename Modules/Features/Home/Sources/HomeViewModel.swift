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

    @ObservationIgnored private let fetchItems: any FetchItemsUseCase
    @ObservationIgnored private let router: any Routing

    public init(fetchItems: any FetchItemsUseCase, router: any Routing) {
        self.fetchItems = fetchItems
        self.router = router
    }

    public func load() async {
        state = .loading
        do {
            state = try await .loaded(fetchItems.execute())
        } catch {
            state = .failed(error)
        }
    }

    public func select(_ item: Item) {
        router.push(HomeRoute.detail(id: item.id))
    }
}
