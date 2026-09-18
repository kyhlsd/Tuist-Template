//
//  AppContainer+Home.swift
//  TuistApp
//

import Home
import HomeInterface
import Navigation
import SwiftUI

extension AppContainer {
    /// Home 탭의 루트 화면.
    func makeHomeView(router: any Routing) -> HomeView {
        HomeView(viewModel: HomeViewModel(repository: itemRepository, router: router))
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
