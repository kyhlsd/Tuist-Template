//
//  AppContainer+Navigation.swift
//  TuistApp
//

import Navigation
import SwiftUI

extension AppContainer {
    /// `AppRoute` 를 화면으로 바꾼다. 탭 스택이든 모달이든 여기를 거쳐 피처별 `makeView(for:)` 로 위임한다.
    ///
    /// - Parameter router: 이 화면이 놓일 문맥(탭 또는 모달)의 `Routing`. 화면의 뷰모델이 이동을 요청해야 하면
    ///   이 값을 넘긴다. 다른 문맥의 라우터를 넘기면 push 가 엉뚱한 스택에 쌓인다.
    @ViewBuilder
    func makeView(for route: AppRoute, router _: any Routing) -> some View {
        switch route {
        case let .home(route):
            // Home 상세는 다른 화면으로 이동하지 않으므로 라우터가 필요 없다.
            makeView(for: route)
        }
    }
}
