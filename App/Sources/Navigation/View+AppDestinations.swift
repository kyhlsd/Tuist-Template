//
//  View+AppDestinations.swift
//  TuistApp
//

import HomeInterface
import SwiftUI

extension View {
    /// 앱의 모든 Route → 화면 매핑.
    ///
    /// 피처를 추가하면 그 피처 Interface 의 Route 타입으로 한 줄을 더한다.
    /// 등록되지 않은 Route 를 push 하면 SwiftUI 는 아무 화면도 띄우지 않고 경고만 남긴다.
    func appDestinations(_ container: AppContainer) -> some View {
        navigationDestination(for: HomeRoute.self) { route in
            container.makeView(for: route)
        }
    }
}
