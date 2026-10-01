//
//  AppContainer+Home.swift
//  TuistApp
//

import Domain
import Home
import HomeInterface
import Navigation
import SwiftUI

extension AppContainer {
    /// Home 탭의 루트 화면.
    ///
    /// 부르는 `body` 가 다시 평가될 때마다 `HomeViewModel` 이 새로 만들어진다. 화면은 `@State` 로 처음 인스턴스만
    /// 쓰므로 나머지는 바로 버려진다. 그래서 뷰모델 `init` 에는 부수효과(호출 시작, 구독, 로그)를 두지 않는다.
    func makeHomeView(router: any Routing) -> HomeView {
        HomeView(
            viewModel: HomeViewModel(
                fetchItems: DefaultFetchItemsUseCase(repository: itemRepository),
                router: router
            )
        )
    }

    /// `HomeRoute` 를 화면으로 바꾼다. 어느 탭의 스택에서 push 되든 여기를 거친다.
    @ViewBuilder
    func makeView(for route: HomeRoute) -> some View {
        switch route {
        case let .detail(id):
            HomeDetailView(itemID: id)
        }
    }
}
