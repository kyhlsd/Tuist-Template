//
//  TabRootView.swift
//  TuistApp
//

import SwiftUI

/// 탭 하나의 내비게이션 스택.
///
/// 스택은 `AppRouter` 가 탭별로 가지므로 탭을 오가도 각 탭의 경로가 유지된다.
/// 어느 탭에서든 앱의 모든 Route 로 이동할 수 있도록 `appDestinations` 를 붙인다.
struct TabRootView: View {
    let tab: AppTab
    let container: AppContainer
    @Bindable var router: AppRouter

    var body: some View {
        NavigationStack(path: $router[path: tab]) {
            root
                .appDestinations(container, router: router.router(for: tab))
        }
    }

    @ViewBuilder
    private var root: some View {
        switch tab {
        case .home:
            container.makeHomeView(router: router.router(for: tab))
        }
    }
}
