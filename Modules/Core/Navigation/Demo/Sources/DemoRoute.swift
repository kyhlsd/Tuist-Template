//
//  DemoRoute.swift
//  NavigationDemo
//

import Navigation

/// 데모에서 push·present 하는 화면.
///
/// `Route` 가 `nonisolated` 이므로 모듈의 MainActor 기본 격리를 벗어나 순수 값으로 둔다.
nonisolated enum DemoRoute: Route {
    case page(depth: Int)
    case modal
}
