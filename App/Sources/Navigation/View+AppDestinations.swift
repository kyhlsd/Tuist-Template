//
//  View+AppDestinations.swift
//  TuistApp
//

import Navigation
import SwiftUI

extension View {
    /// 앱의 모든 Route → 화면 매핑. 스택 루트에 한 번만 붙인다.
    ///
    /// 스택 원소는 모두 `AppRoute` 이므로 등록은 하나다. 피처를 추가하면
    /// `AppContainer.makeView(for:router:)` 의 분기를 늘린다.
    ///
    /// - Parameter router: 이 스택이 속한 문맥의 `Routing`. push 된 화면도 같은 문맥에서 이동한다.
    func appDestinations(_ container: AppContainer, router: any Routing) -> some View {
        navigationDestination(for: AppRoute.self) { route in
            container.makeView(for: route, router: router)
        }
    }
}
