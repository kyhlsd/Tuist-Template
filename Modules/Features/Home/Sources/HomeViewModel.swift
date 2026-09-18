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
/// Repository 와 Router 는 프로토콜로 주입받는다. 실제 구현은 App 이,
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

    @ObservationIgnored private let repository: any ItemRepository
    @ObservationIgnored private let router: any Routing

    public init(repository: any ItemRepository, router: any Routing) {
        self.repository = repository
        self.router = router
    }

    public func load() async {
        state = .loading
        do {
            state = try await .loaded(repository.fetchItems())
        } catch {
            state = .failed(error)
        }
    }

    public func select(_ item: Item) {
        router.push(HomeRoute.detail(id: item.id))
    }
}
