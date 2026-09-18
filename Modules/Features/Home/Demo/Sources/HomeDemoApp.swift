//
//  HomeDemoApp.swift
//  HomeDemo
//
//  Home 만 띄우는 데모 앱. 서버 대신 DomainTesting 의 스텁을 주입한다.
//  결과를 .failure(.unavailable) 로 바꾸면 오류 화면을 바로 확인할 수 있다.
//
//  앱의 RootView 가 하는 일(스택 생성, Route → 화면 매핑)을 Home 범위에서만 흉내 낸다.
//

import DesignSystem
import Domain
import DomainTesting
import Home
import HomeInterface
import Navigation
import SwiftUI

@main
struct HomeDemoApp: App {
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView(
                    viewModel: HomeViewModel(
                        repository: StubItemRepository(result: .success(Item.samples)),
                        router: router
                    )
                )
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case let .detail(id):
                        HomeDetailView(itemID: id)
                    }
                }
            }
            .theme(.standard)
        }
    }
}
